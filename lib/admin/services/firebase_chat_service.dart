import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/firebase_chat_models.dart';
import 'onesignal_service.dart';
import 'cloudinary_service.dart';
import '../../utils/logger.dart';

class FirebaseChatService {
  static final FirebaseChatService _instance = FirebaseChatService._internal();
  factory FirebaseChatService() => _instance;
  FirebaseChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final rtdb.FirebaseDatabase _database = rtdb.FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  final OneSignalService _oneSignalService = OneSignalService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Stream controllers
  final StreamController<List<FirebaseChat>> _chatsController =
      StreamController<List<FirebaseChat>>.broadcast();
  final StreamController<List<FirebaseChatMessage>> _messagesController =
      StreamController<List<FirebaseChatMessage>>.broadcast();
  final StreamController<ChatStatistics> _statisticsController =
      StreamController<ChatStatistics>.broadcast();
  StreamController<List<FirebaseUser>>? _usersStreamController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _usersSnapshotSubscription;

  // Pagination state
  DocumentSnapshot? _lastChatDoc;
  DocumentSnapshot? _lastMessageDoc;
  static const int _pageSize = 20;

  // Streams
  Stream<List<FirebaseChat>> get chatsStream => _chatsController.stream;
  Stream<List<FirebaseChatMessage>> get messagesStream =>
      _messagesController.stream;
  Stream<ChatStatistics> get statisticsStream => _statisticsController.stream;

  // Current user
  FirebaseUser? _currentUser;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  // Flag to prevent race conditions in chat listening
  bool _isListeningToChats = false;

  /// Initialize the chat service
  Future<void> initialize() async {
    // Load user first (required for listening to chats)
    await _loadCurrentUser();

    // Start listening to chats immediately
    _listenToChats();
  }

  /// Load current user from Firestore
  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      Logger.warning('No authenticated user found');
      return;
    }

    // Try to load from users collection first
    var doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      try {
        _currentUser = FirebaseUser.fromJson({'id': doc.id, ...doc.data()!});
        Logger.debug(
          'Loaded user from users collection: ${_currentUser!.name} (${_currentUser!.role})',
        );
        return;
      } catch (e) {
        Logger.error('Error parsing user from users collection', e);
      }
    }

    // Try to load from admins collection
    doc = await _firestore.collection('admins').doc(user.uid).get();
    if (doc.exists) {
      try {
        final data = doc.data()!;
        _currentUser = FirebaseUser(
          id: doc.id,
          name:
              data['name'] ??
              data['full_name'] ??
              user.displayName ??
              user.email?.split('@').first ??
              'Admin User',
          email: data['email'] ?? user.email ?? 'admin@energysmart.com',
          role: 'admin',
          photoUrl: data['photo_url'] ?? data['photoUrl'] ?? user.photoURL,
          createdAt:
              (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
        );
        Logger.debug(
          'Loaded admin from admins collection: ${_currentUser!.name}',
        );

        // Also save to users collection for consistency
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(_currentUser!.toJson());
        return;
      } catch (e) {
        Logger.error('Error parsing admin from admins collection', e);
      }
    }

    // If user doc doesn't exist in either collection, create a minimal admin user document
    Logger.info('User document not found, creating new admin user document');
    final newUser = FirebaseUser(
      id: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'Admin User',
      email: user.email ?? 'admin@energysmart.com',
      role: 'admin',
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    await _firestore.collection('users').doc(user.uid).set(newUser.toJson());
    _currentUser = newUser;
    Logger.info('Created new user document: ${_currentUser!.name}');
  }

  /// Listen to chats for current admin
  void _listenToChats() {
    if (_currentUser == null) {
      Logger.warning('Cannot listen to chats: current user is null');
      if (!_chatsController.isClosed) {
        try {
          _chatsController.add([]);
        } catch (e) {
          Logger.error('Error adding empty chats to controller', e);
        }
      }
      return;
    }

    // Prevent multiple simultaneous queries
    if (_isListeningToChats) {
      Logger.debug('[listenToChats] Already listening, skipping');
      return;
    }

    _isListeningToChats = true;

    // For admin users, try multiple query strategies with fallback
    // Strategy 1: Query chats where participants array contains 'admin' string
    // Strategy 2: Query chats where participants array contains admin UID
    // Strategy 3: Client-side filtering as last resort
    Query base;

    if (_currentUser!.role == 'admin') {
      // Primary query: chats where participants array contains 'admin' string
      base = _firestore
          .collection('chats')
          .where('participants', arrayContains: 'admin');
    } else {
      // For regular users, only show chats where they are a participant
      base = _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUser!.id);
    }

    // Client-side filtering fallback (last resort)
    void _tryQueryAllChats() {
      _chatsSubscription?.cancel();
      Logger.debug('[listenToChats] Trying client-side filtering fallback');
      _chatsSubscription = _firestore
          .collection('chats')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize * 2) // Get more to account for filtering
          .snapshots()
          .listen(
            (snapshot) {
              try {
                final allChats =
                    snapshot.docs
                        .map((doc) {
                          try {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return null;
                            return FirebaseChat.fromJson({
                              'id': doc.id,
                              ...data,
                            });
                          } catch (e) {
                            Logger.error('Error parsing chat ${doc.id}', e);
                            return null;
                          }
                        })
                        .whereType<FirebaseChat>()
                        .toList();

                // Filter chats that contain admin (either 'admin' string or admin UID)
                final filteredChats =
                    allChats.where((chat) {
                      if (_currentUser!.role == 'admin') {
                        return chat.participants.contains('admin') ||
                            chat.participants.contains(_currentUser!.id);
                      }
                      return chat.participants.contains(_currentUser!.id);
                    }).toList();

                if (snapshot.docs.isNotEmpty) {
                  _lastChatDoc = snapshot.docs.last;
                }
                Logger.debug(
                  '[listenToChats] Client-side filter found ${filteredChats.length} chats',
                );
                if (!_chatsController.isClosed) {
                  try {
                    _chatsController.add(filteredChats);
                  } catch (e) {
                    Logger.error(
                      'Error adding filtered chats to controller',
                      e,
                    );
                  }
                }
              } catch (e) {
                Logger.error('Error processing all chats', e);
                if (!_chatsController.isClosed) {
                  try {
                    _chatsController.add([]);
                  } catch (e2) {
                    Logger.error('Error adding empty chats to controller', e2);
                  }
                }
              }
            },
            onError: (error) {
              Logger.error('Error listening to all chats', error);
              if (!_chatsController.isClosed) {
                try {
                  _chatsController.add([]);
                } catch (e) {
                  Logger.error('Error adding empty chats to controller', e);
                }
              }
            },
          );
    }

    // Fallback query using admin UID (for existing chats without 'admin' string)
    void startFallback() {
      _chatsSubscription?.cancel();

      Query fallbackQuery;
      if (_currentUser!.role == 'admin') {
        Logger.debug(
          '[listenToChats] Trying fallback query with admin UID: ${_currentUser!.id}',
        );
        // Fallback: Query chats where participants contains admin UID
        fallbackQuery = _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUser!.id);
      } else {
        fallbackQuery = base;
      }

      _chatsSubscription = fallbackQuery
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen(
            (snapshot) {
              try {
                final chats =
                    snapshot.docs
                        .map((doc) {
                          try {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return null;
                            return FirebaseChat.fromJson({
                              'id': doc.id,
                              ...data,
                            });
                          } catch (e) {
                            Logger.error('Error parsing chat ${doc.id}', e);
                            return null;
                          }
                        })
                        .whereType<FirebaseChat>()
                        .toList();
                if (snapshot.docs.isNotEmpty) {
                  _lastChatDoc = snapshot.docs.last;
                }
                Logger.debug(
                  '[listenToChats] Fallback query found ${chats.length} chats',
                );
                if (!_chatsController.isClosed) {
                  try {
                    _chatsController.add(chats);
                  } catch (e) {
                    Logger.error('Error adding chats to controller', e);
                  }
                }
              } catch (e) {
                Logger.error('Error processing chats', e);
                // Try client-side filtering as last resort
                _tryQueryAllChats();
              }
            },
            onError: (error) {
              Logger.error('Error listening to chats (fallback)', error);
              // Try client-side filtering as last resort
              _tryQueryAllChats();
            },
          );
    }

    // Primary query with 'admin' string
    void startPrimary() {
      _chatsSubscription?.cancel();
      Logger.debug(
        '[listenToChats] Starting primary query with "admin" string',
      );
      _chatsSubscription = base
          .orderBy('lastMessageTime', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen(
            (snapshot) {
              try {
                final chats =
                    snapshot.docs
                        .map((doc) {
                          try {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return null;
                            return FirebaseChat.fromJson({
                              'id': doc.id,
                              ...data,
                            });
                          } catch (e) {
                            Logger.error('Error parsing chat ${doc.id}', e);
                            return null;
                          }
                        })
                        .whereType<FirebaseChat>()
                        .toList();
                if (snapshot.docs.isNotEmpty) {
                  _lastChatDoc = snapshot.docs.last;
                }

                // If no chats found with 'admin' string and user is admin, try fallback
                if (chats.isEmpty && _currentUser!.role == 'admin') {
                  Logger.debug(
                    '[listenToChats] No chats found with "admin" string, trying fallback query',
                  );
                  startFallback();
                  return;
                }

                Logger.debug(
                  '[listenToChats] Primary query found ${chats.length} chats',
                );
                if (!_chatsController.isClosed) {
                  try {
                    _chatsController.add(chats);
                  } catch (e) {
                    Logger.error('Error adding chats to controller', e);
                  }
                }
              } catch (e) {
                Logger.error('Error processing chats', e);
                if (_currentUser!.role == 'admin') {
                  startFallback();
                } else {
                  if (!_chatsController.isClosed) {
                    try {
                      _chatsController.add([]);
                    } catch (e2) {
                      Logger.error(
                        'Error adding empty chats to controller',
                        e2,
                      );
                    }
                  }
                }
              }
            },
            onError: (error) {
              Logger.error('Error listening to chats (primary)', error);
              // Fallback to createdAt ordering if lastMessageTime is missing or index issue
              if (_currentUser!.role == 'admin') {
                startFallback();
              } else {
                if (!_chatsController.isClosed) {
                  try {
                    _chatsController.add([]);
                  } catch (e) {
                    Logger.error('Error adding empty chats to controller', e);
                  }
                }
              }
            },
          );
    }

    startPrimary();
  }

  /// Fetch more chats (pagination)
  Future<List<FirebaseChat>> loadMoreChats() async {
    if (_currentUser == null || _lastChatDoc == null) return [];
    try {
      Query query;

      if (_currentUser!.role == 'admin') {
        // Primary: Query chats where participants array contains 'admin' string
        query = _firestore
            .collection('chats')
            .where('participants', arrayContains: 'admin');
      } else {
        // For regular users, only their chats
        query = _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUser!.id);
      }

      // Try primary query with lastMessageTime ordering
      try {
        final snapshot =
            await query
                .orderBy('lastMessageTime', descending: true)
                .startAfterDocument(_lastChatDoc!)
                .limit(_pageSize)
                .get();

        if (snapshot.docs.isEmpty) {
          // If empty and user is admin, try fallback
          if (_currentUser!.role == 'admin') {
            Logger.debug(
              '[loadMoreChats] No chats found with "admin" string, trying fallback',
            );
            return await _loadMoreChatsFallback();
          }
          return [];
        }

        _lastChatDoc = snapshot.docs.last;
        final chats =
            snapshot.docs
                .map((doc) {
                  try {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return null;
                    return FirebaseChat.fromJson({'id': doc.id, ...data});
                  } catch (e) {
                    Logger.debug('Error parsing chat ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<FirebaseChat>()
                .toList();

        return chats;
      } catch (e) {
        // If lastMessageTime ordering fails, try createdAt ordering
        Logger.debug(
          '[loadMoreChats] lastMessageTime ordering failed, trying createdAt',
        );
        final snapshot =
            await query
                .orderBy('createdAt', descending: true)
                .startAfterDocument(_lastChatDoc!)
                .limit(_pageSize)
                .get();

        if (snapshot.docs.isEmpty) {
          // If still empty and user is admin, try fallback
          if (_currentUser!.role == 'admin') {
            return await _loadMoreChatsFallback();
          }
          return [];
        }

        _lastChatDoc = snapshot.docs.last;
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return null;
                return FirebaseChat.fromJson({'id': doc.id, ...data});
              } catch (e) {
                Logger.debug('Error parsing chat ${doc.id}: $e');
                return null;
              }
            })
            .whereType<FirebaseChat>()
            .toList();
      }
    } catch (e) {
      Logger.error('Error loading more chats', e);
      // Try fallback if user is admin
      if (_currentUser!.role == 'admin') {
        return await _loadMoreChatsFallback();
      }
      return [];
    }
  }

  /// Fallback method for loading more chats using admin UID
  Future<List<FirebaseChat>> _loadMoreChatsFallback() async {
    if (_currentUser == null || _lastChatDoc == null) return [];
    try {
      Logger.debug(
        '[loadMoreChats] Using fallback query with admin UID: ${_currentUser!.id}',
      );
      final query = _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUser!.id);

      // Try with createdAt ordering
      final snapshot =
          await query
              .orderBy('createdAt', descending: true)
              .startAfterDocument(_lastChatDoc!)
              .limit(_pageSize)
              .get();

      if (snapshot.docs.isEmpty) return [];

      _lastChatDoc = snapshot.docs.last;
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return null;
              return FirebaseChat.fromJson({'id': doc.id, ...data});
            } catch (e) {
              Logger.debug('Error parsing chat ${doc.id}: $e');
              return null;
            }
          })
          .whereType<FirebaseChat>()
          .toList();
    } catch (e) {
      Logger.error('Error in loadMoreChats fallback', e);
      return [];
    }
  }

  /// Parse messages from Firestore documents
  List<FirebaseChatMessage> _parseMessages(
    List<QueryDocumentSnapshot> docs,
    String chatId,
  ) {
    final messages = <FirebaseChatMessage>[];

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          Logger.warning('Message ${doc.id} has null data');
          continue;
        }

        // Log field structure for debugging
        if (docs.length <= 3) {
          Logger.debug('Message ${doc.id} fields: ${data.keys.join(", ")}');
          Logger.debug(
            '   createdAt: ${data['createdAt']} (${data['createdAt']?.runtimeType})',
          );
          Logger.debug(
            '   timestamp: ${data['timestamp']} (${data['timestamp']?.runtimeType})',
          );
        }

        final message = FirebaseChatMessage.fromJson({'id': doc.id, ...data});
        messages.add(message);
      } catch (e, stackTrace) {
        Logger.error('Error parsing message ${doc.id}', e, stackTrace);
        Logger.debug('   Data: ${doc.data()}');
      }
    }

    return messages;
  }

  /// Listen to messages for a specific chat thread (per admin guide: chats/{chatId}/messages)
  void listenToUserMessages(String userId, {String? chatId}) {
    _messagesSubscription?.cancel();

    // Get or create chat thread if chatId not provided
    if (chatId == null) {
      getOrCreateChatWithUser(userId)
          .then((id) {
            _listenToChatMessages(id);
          })
          .catchError((e) {
            Logger.error('Error getting chat thread', e);
            _messagesController.addError(
              'Failed to get chat thread: $e',
              StackTrace.current,
            );
          });
    } else {
      _listenToChatMessages(chatId);
    }
  }

  /// Internal method to listen to messages in a chat thread with fallback logic
  void _listenToChatMessages(String chatId) {
    _messagesSubscription?.cancel();

    Logger.debug(
      '[listenToChatMessages] Listening to messages for chat $chatId',
    );

    // Declare fallback functions
    late void Function() tryFallbackQuery;
    late void Function() tryUnorderedQuery;
    bool fallbackAttempted = false;
    bool unorderedAttempted = false;

    // Final fallback: unordered query with manual sorting
    tryUnorderedQuery = () {
      if (unorderedAttempted) {
        Logger.debug(
          '[listenToChatMessages] Unordered query already attempted for chat $chatId',
        );
        return;
      }
      unorderedAttempted = true;

      Logger.debug(
        '[listenToChatMessages] Attempting unordered query for chat $chatId',
      );

      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(_pageSize * 2); // Get more to account for manual sorting

      _messagesSubscription?.cancel();
      _messagesSubscription = query.snapshots().listen(
        (snapshot) {
          try {
            Logger.debug(
              '[listenToChatMessages] Unordered query received ${snapshot.docs.length} messages',
            );

            // Manual sort by timestamp or createdAt
            final sortedDocs = List<QueryDocumentSnapshot>.from(snapshot.docs);
            sortedDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              Timestamp? aTime = aData['timestamp'] as Timestamp?;
              Timestamp? bTime = bData['timestamp'] as Timestamp?;

              // Fallback to createdAt
              if (aTime == null) aTime = aData['createdAt'] as Timestamp?;
              if (bTime == null) bTime = bData['createdAt'] as Timestamp?;

              // If still null, use document creation time
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime); // Descending
            });

            // Take only the first pageSize
            final limitedDocs = sortedDocs.take(_pageSize).toList();
            final messages = _parseMessages(limitedDocs, chatId);

            if (limitedDocs.isNotEmpty) {
              _lastMessageDoc = limitedDocs.last;
            }

            if (!_messagesController.isClosed) {
              try {
                _messagesController.add(messages);
              } catch (e) {
                Logger.error('Error adding messages to controller', e);
              }
            }

            // Mark messages as seen by admin
            if (messages.isNotEmpty && _currentUser != null) {
              _markChatMessagesAsSeen(chatId, messages);
            }
          } catch (e, stackTrace) {
            Logger.error(
              '[listenToChatMessages] Error processing unordered messages',
              e,
              stackTrace,
            );
            if (!_messagesController.isClosed) {
              try {
                _messagesController.addError(
                  'Error processing messages: $e',
                  StackTrace.current,
                );
              } catch (e2) {
                Logger.error('Error adding error to messages controller', e2);
              }
            }
          }
        },
        onError: (error, stackTrace) {
          final errorStr = error.toString();
          Logger.error(
            '[listenToChatMessages] Unordered query failed: $errorStr',
            null,
            stackTrace,
          );
          if (!_messagesController.isClosed) {
            try {
              _messagesController.addError(
                'Failed to load messages: $errorStr',
                stackTrace,
              );
            } catch (e) {
              Logger.error('Error adding error to messages controller', e);
            }
          }
        },
      );
    };

    // Fallback query with createdAt
    tryFallbackQuery = () {
      if (fallbackAttempted) {
        Logger.debug(
          '[listenToChatMessages] Fallback query already attempted for chat $chatId',
        );
        // If fallback already attempted, go straight to unordered
        tryUnorderedQuery();
        return;
      }
      fallbackAttempted = true;

      Logger.debug(
        '[listenToChatMessages] Attempting fallback query with createdAt for chat $chatId',
      );

      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      _messagesSubscription?.cancel();
      _messagesSubscription = query.snapshots().listen(
        (snapshot) {
          try {
            Logger.debug(
              '[listenToChatMessages] Fallback query received ${snapshot.docs.length} messages',
            );
            final messages = _parseMessages(snapshot.docs, chatId);

            if (snapshot.docs.isNotEmpty) {
              _lastMessageDoc = snapshot.docs.last;
            }

            if (!_messagesController.isClosed) {
              try {
                _messagesController.add(messages);
              } catch (e) {
                Logger.error('Error adding messages to controller', e);
              }
            }

            // Mark messages as seen by admin
            if (messages.isNotEmpty && _currentUser != null) {
              _markChatMessagesAsSeen(chatId, messages);
            }
            if (messages.isEmpty) {
              Logger.debug(
                '[listenToChatMessages] Fallback query returned no messages, trying unordered query',
              );
              tryUnorderedQuery();
            }
          } catch (e, stackTrace) {
            Logger.error(
              '[listenToChatMessages] Error processing fallback messages',
              e,
              stackTrace,
            );
            if (!_messagesController.isClosed) {
              try {
                _messagesController.addError(
                  'Error processing messages: $e',
                  StackTrace.current,
                );
              } catch (e2) {
                Logger.error('Error adding error to messages controller', e2);
              }
            }
          }
        },
        onError: (error, stackTrace) {
          final errorStr = error.toString();
          Logger.error(
            '[listenToChatMessages] Fallback query failed: $errorStr',
          );
          Logger.warning(
            '[listenToChatMessages] Trying final fallback: unordered query',
          );
          tryUnorderedQuery();
        },
      );
    };

    // Primary query with timestamp
    final query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize);

    _messagesSubscription = query.snapshots().listen(
      (snapshot) {
        try {
          Logger.debug(
            '[listenToChatMessages] Primary query received ${snapshot.docs.length} messages',
          );

          final messages = _parseMessages(snapshot.docs, chatId);

          if (snapshot.docs.isNotEmpty) {
            _lastMessageDoc = snapshot.docs.last;
          }

          if (!_messagesController.isClosed) {
            try {
              _messagesController.add(messages);
            } catch (e) {
              Logger.error('Error adding messages to controller', e);
            }
          }

          // Mark messages as seen by admin (reset unread count)
          if (messages.isNotEmpty && _currentUser != null) {
            _markChatMessagesAsSeen(chatId, messages);
          }

          if (messages.isEmpty) {
            Logger.debug(
              '[listenToChatMessages] Primary query returned no messages, trying fallback',
            );
            tryFallbackQuery();
          }
        } catch (e, stackTrace) {
          Logger.error(
            '[listenToChatMessages] Error processing messages',
            e,
            stackTrace,
          );
          if (!_messagesController.isClosed) {
            try {
              _messagesController.addError(
                'Error processing messages: $e',
                StackTrace.current,
              );
            } catch (e2) {
              Logger.error('Error adding error to messages controller', e2);
            }
          }
        }
      },
      onError: (error, stackTrace) {
        final errorStr = error.toString();
        Logger.error('[listenToChatMessages] Primary query failed: $errorStr');
        Logger.warning(
          '[listenToChatMessages] Trying fallback query with createdAt',
        );
        tryFallbackQuery();
      },
    );
  }

  /// Listen to messages for a specific chat with fallback mechanism
  void listenToMessages(String chatId) {
    _messagesSubscription?.cancel();

    // Declare functions first
    late void Function() tryFallbackQuery;
    late void Function() tryUnorderedQuery;

    // Final fallback: unordered query with manual sorting
    tryUnorderedQuery = () {
      Logger.debug(
        '[listenToMessages] Attempting unordered query for chat $chatId',
      );

      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .limit(_pageSize * 2); // Get more to account for manual sorting

      _messagesSubscription?.cancel();
      _messagesSubscription = query.snapshots().listen(
        (snapshot) {
          try {
            Logger.debug(
              '[listenToMessages] Unordered query succeeded: ${snapshot.docs.length} messages',
            );

            // Manually sort by createdAt or timestamp
            final sortedDocs =
                snapshot.docs.toList()..sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();

                  // Try createdAt first
                  Timestamp? aTime = aData['createdAt'] as Timestamp?;
                  Timestamp? bTime = bData['createdAt'] as Timestamp?;

                  // Fallback to timestamp
                  if (aTime == null) aTime = aData['timestamp'] as Timestamp?;
                  if (bTime == null) bTime = bData['timestamp'] as Timestamp?;

                  // If still null, use document creation time
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;

                  return bTime.compareTo(aTime); // Descending
                });

            // Take only the first pageSize
            final limitedDocs = sortedDocs.take(_pageSize).toList();
            final messages = _parseMessages(limitedDocs, chatId);

            if (limitedDocs.isNotEmpty) {
              _lastMessageDoc = limitedDocs.last;
            }

            _messagesController.add(messages);

            // Mark messages as seen by admin
            if (messages.isNotEmpty) {
              _markMessagesAsSeen(chatId, messages);
            }
          } catch (e, stackTrace) {
            Logger.error(
              '[listenToMessages] Error processing unordered messages',
              e,
              stackTrace,
            );
            _messagesController.addError(
              'Error processing messages: $e',
              StackTrace.current,
            );
          }
        },
        onError: (error, stackTrace) {
          final errorStr = error.toString();
          Logger.error(
            '[listenToMessages] Unordered query failed: $errorStr',
            null,
            stackTrace,
          );
          _messagesController.addError(
            'Failed to load messages: $errorStr',
            stackTrace,
          );
        },
      );
    };

    // Try fallback query with createdAt
    tryFallbackQuery = () {
      Logger.debug(
        '[listenToMessages] Attempting fallback query with createdAt for chat $chatId',
      );

      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      _messagesSubscription?.cancel();
      _messagesSubscription = query.snapshots().listen(
        (snapshot) {
          try {
            Logger.debug(
              '[listenToMessages] Fallback query succeeded: ${snapshot.docs.length} messages',
            );
            final messages = _parseMessages(snapshot.docs, chatId);

            if (snapshot.docs.isNotEmpty) {
              _lastMessageDoc = snapshot.docs.last;
            }

            _messagesController.add(messages);

            // Mark messages as seen by admin
            if (messages.isNotEmpty) {
              _markMessagesAsSeen(chatId, messages);
            }
          } catch (e, stackTrace) {
            Logger.error(
              '[listenToMessages] Error processing fallback messages',
              e,
              stackTrace,
            );
            _messagesController.addError(
              'Error processing messages: $e',
              StackTrace.current,
            );
          }
        },
        onError: (error, stackTrace) {
          final errorStr = error.toString();
          Logger.error('[listenToMessages] Fallback query failed: $errorStr');
          Logger.warning(
            '[listenToMessages] Trying final fallback: unordered query',
          );
          tryUnorderedQuery();
        },
      );
    };

    // Try primary query with timestamp (matches database structure)
    void tryPrimaryQuery() {
      Logger.debug(
        '[listenToMessages] Attempting primary query with timestamp for chat $chatId',
      );

      final query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      _messagesSubscription = query.snapshots().listen(
        (snapshot) {
          try {
            Logger.debug(
              '[listenToMessages] Primary query succeeded: ${snapshot.docs.length} messages',
            );
            final messages = _parseMessages(snapshot.docs, chatId);

            if (snapshot.docs.isNotEmpty) {
              _lastMessageDoc = snapshot.docs.last;
            }

            _messagesController.add(messages);

            // Mark messages as seen by admin
            if (messages.isNotEmpty) {
              _markMessagesAsSeen(chatId, messages);
            }
          } catch (e, stackTrace) {
            Logger.error(
              '[listenToMessages] Error processing messages',
              e,
              stackTrace,
            );
            _messagesController.addError(
              'Error processing messages: $e',
              StackTrace.current,
            );
          }
        },
        onError: (error, stackTrace) {
          final errorStr = error.toString();
          Logger.error('[listenToMessages] Primary query failed: $errorStr');

          // Check if it's a missing index error
          if (errorStr.contains('index') || errorStr.contains('Index')) {
            Logger.warning(
              '[listenToMessages] Missing index detected, trying fallback query with createdAt',
            );
            tryFallbackQuery();
          } else {
            // Try fallback anyway
            Logger.warning(
              '[listenToMessages] Trying fallback query with createdAt',
            );
            tryFallbackQuery();
          }
        },
      );
    }

    // Start with primary query
    tryPrimaryQuery();
  }

  /// Fetch more messages for chat (pagination) - per admin guide structure
  Future<List<FirebaseChatMessage>> loadMoreUserMessages(String chatId) async {
    if (_lastMessageDoc == null) {
      Logger.warning(
        '[loadMoreUserMessages] No last document, cannot paginate',
      );
      return [];
    }

    try {
      Logger.debug(
        '[loadMoreUserMessages] Loading more messages for chat $chatId',
      );
      final snapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .startAfterDocument(_lastMessageDoc!)
              .limit(_pageSize)
              .get();

      if (snapshot.docs.isEmpty) {
        Logger.debug('[loadMoreUserMessages] No more messages');
        return [];
      }

      _lastMessageDoc = snapshot.docs.last;

      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return null;

              return FirebaseChatMessage.fromJson({
                'id': doc.id,
                'chatId': chatId,
                ...data,
              });
            } catch (e) {
              Logger.error('Error parsing message ${doc.id}', e);
              return null;
            }
          })
          .whereType<FirebaseChatMessage>()
          .toList();
    } catch (e) {
      Logger.error('[loadMoreUserMessages] Error loading more messages', e);
      return [];
    }
  }

  /// Fetch more messages for chat (pagination) with fallback mechanism
  Future<List<FirebaseChatMessage>> loadMoreMessages(String chatId) async {
    if (_lastMessageDoc == null) {
      Logger.warning('[loadMoreMessages] No last document, cannot paginate');
      return [];
    }

    // Try primary query with timestamp (matches database structure)
    try {
      Logger.debug(
        '[loadMoreMessages] Attempting primary query with timestamp',
      );
      final snapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .startAfterDocument(_lastMessageDoc!)
              .limit(_pageSize)
              .get();

      if (snapshot.docs.isEmpty) {
        Logger.debug(
          '✅ [loadMoreMessages] Primary query succeeded but no more messages',
        );
        return [];
      }

      Logger.debug(
        '[loadMoreMessages] Primary query succeeded: ${snapshot.docs.length} messages',
      );
      _lastMessageDoc = snapshot.docs.last;
      return _parseMessages(snapshot.docs, chatId);
    } catch (e) {
      final errorStr = e.toString();
      Logger.error('[loadMoreMessages] Primary query failed: $errorStr');

      // Try fallback query with createdAt
      try {
        Logger.debug(
          '🔍 [loadMoreMessages] Attempting fallback query with createdAt',
        );
        final snapshot =
            await _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .startAfterDocument(_lastMessageDoc!)
                .limit(_pageSize)
                .get();

        if (snapshot.docs.isEmpty) {
          Logger.debug(
            '✅ [loadMoreMessages] Fallback query succeeded but no more messages',
          );
          return [];
        }

        Logger.debug(
          '✅ [loadMoreMessages] Fallback query succeeded: ${snapshot.docs.length} messages',
        );
        _lastMessageDoc = snapshot.docs.last;
        return _parseMessages(snapshot.docs, chatId);
      } catch (e2) {
        Logger.error('[loadMoreMessages] Fallback query also failed', e2);
        Logger.warning(
          '[loadMoreMessages] Pagination not available with unordered query',
        );
        return [];
      }
    }
  }

  /// Typing indicators
  Future<void> setTyping(String chatId, bool isTyping) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typing.${_currentUser!.id}': isTyping,
      });
    } catch (_) {}
  }

  Stream<bool> typingStream(String chatId, String otherUserId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return false;
      final typing = (data['typing'] as Map<String, dynamic>?) ?? {};
      final v = typing[otherUserId];
      return v is bool ? v : false;
    });
  }

  /// Debug helper: print latest chat and a few messages for current admin
  Future<void> debugPrintLatestChat() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      Logger.warning('No authenticated user for chat debug');
      return;
    }
    try {
      final q =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: uid)
              .orderBy('lastMessageTime', descending: true)
              .limit(1)
              .get();

      if (q.docs.isEmpty) {
        Logger.debug('No chats for $uid');
        return;
      }
      final chat = q.docs.first;
      Logger.debug('CHAT ${chat.id}: ${chat.data()}');

      final msgs =
          await chat.reference
              .collection('messages')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .get();
      for (final m in msgs.docs) {
        Logger.debug('MSG ${m.id}: ${m.data()}');
      }
    } catch (e) {
      Logger.error('Chat debug error', e);
    }
  }

  /// Debug method to inspect message structure in Firestore
  Future<void> debugMessages(String chatId) async {
    Logger.debug('[debugMessages] Inspecting messages for chat: $chatId');

    try {
      // Get all messages without ordering first
      final messagesRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');

      final allMessagesSnapshot = await messagesRef.limit(10).get();

      Logger.debug(
        '[debugMessages] Total messages found: ${allMessagesSnapshot.docs.length}',
      );

      if (allMessagesSnapshot.docs.isEmpty) {
        Logger.debug('⚠️ [debugMessages] No messages found in Firestore');
        return;
      }

      // Inspect first message structure
      final firstDoc = allMessagesSnapshot.docs.first;
      final firstData = firstDoc.data();
      Logger.debug('[debugMessages] First message structure:');
      Logger.debug('   Document ID: ${firstDoc.id}');
      Logger.debug('   Fields: ${firstData.keys.join(", ")}');

      for (final key in firstData.keys) {
        final value = firstData[key];
        Logger.debug('   $key: $value (${value.runtimeType})');
      }

      // Test createdAt query
      Logger.debug('[debugMessages] Testing createdAt query...');
      try {
        final createdAtQuery =
            await messagesRef
                .orderBy('createdAt', descending: true)
                .limit(5)
                .get();
        Logger.debug(
          '✅ [debugMessages] createdAt query succeeded: ${createdAtQuery.docs.length} messages',
        );
      } catch (e) {
        Logger.error('[debugMessages] createdAt query failed', e);
      }

      // Test timestamp query
      Logger.debug('[debugMessages] Testing timestamp query...');
      try {
        final timestampQuery =
            await messagesRef
                .orderBy('timestamp', descending: true)
                .limit(5)
                .get();
        Logger.debug(
          '✅ [debugMessages] timestamp query succeeded: ${timestampQuery.docs.length} messages',
        );
      } catch (e) {
        Logger.error('[debugMessages] timestamp query failed', e);
      }

      // Show sample messages
      Logger.debug('[debugMessages] Sample messages (first 3):');
      for (int i = 0; i < allMessagesSnapshot.docs.length && i < 3; i++) {
        final doc = allMessagesSnapshot.docs[i];
        final data = doc.data();
        Logger.debug('   Message ${i + 1} (${doc.id}):');
        Logger.debug('     createdAt: ${data['createdAt']}');
        Logger.debug('     timestamp: ${data['timestamp']}');
        Logger.debug('     text: ${data['text']}');
        Logger.debug('     senderId: ${data['senderId']}');
      }
    } catch (e, stackTrace) {
      Logger.error('[debugMessages] Error inspecting messages', e, stackTrace);
    }
  }

  /// Get message count for a chat
  Future<int> getMessageCount(String chatId) async {
    try {
      final snapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .count()
              .get();

      final count = snapshot.count ?? 0;
      Logger.debug('[getMessageCount] Chat $chatId has $count messages');
      return count;
    } catch (e) {
      Logger.error('[getMessageCount] Error getting message count', e);
      return 0;
    }
  }

  /// Create a new chat or return existing between admin and user
  Future<String> createOrGetChat({
    required String userId,
    String? subject,
    ChatPriority priority = ChatPriority.normal,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');
    // Try to find existing chat with same two participants
    final existing =
        await _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUser!.id)
            .get();
    for (final doc in existing.docs) {
      final data = doc.data();
      final parts = List<String>.from(data['participants'] ?? []);
      if (parts.length == 2 && parts.contains(userId)) {
        return doc.id;
      }
    }
    // Create new
    return createChat(userId: userId, subject: subject, priority: priority);
  }

  /// Send a text message to a user (per admin guide: chats/{chatId}/messages)
  Future<void> sendMessageToUser({
    required String userId,
    required String text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    // Get or create chat thread
    final chatId = await getOrCreateChatWithUser(userId);

    final messageId = _uuid.v4();
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    // Create message document with senderId field (per admin guide)
    await messageRef.set({
      'senderId': 'admin', // Use senderId field (per admin guide)
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': MessageStatus.sent.name,
      'chatId': chatId,
      if (replyToId != null) 'replyToId': replyToId,
      if (metadata != null) 'metadata': metadata,
    });

    // Update chat document metadata (per admin guide)
    final lastMessagePreview =
        text.length > 100 ? text.substring(0, 100) : text;
    await _firestore
        .collection('chats')
        .doc(chatId)
        .update({
          'lastMessage': lastMessagePreview,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount.$userId': FieldValue.increment(
            1,
          ), // Increment user's unread count
        })
        .catchError((e) => Logger.error('Error updating chat metadata', e));

    // Send push notification
    await _sendPushNotificationToUser(userId, text);
  }

  /// Send a text message (legacy method - keeps backward compatibility)
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    // Try to extract userId from chat
    // For new structure, chatId might be userId, or we need to get it from chat participants
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData?['participants'] ?? []);
        // Find the user ID (not 'admin' and not current admin user ID)
        final userId = participants.firstWhere(
          (id) => id != 'admin' && id != _currentUser!.id,
          orElse: () => '',
        );
        if (userId.isNotEmpty) {
          // Use new structure
          await sendMessageToUser(
            userId: userId,
            text: text,
            replyToId: replyToId,
            metadata: metadata,
          );
          return;
        }
      }
    } catch (e) {
      Logger.error('Error getting chat data, using old structure', e);
    }

    // Fallback to old structure (backward compatibility)
    final messageId = _uuid.v4();
    final message = FirebaseChatMessage(
      id: messageId,
      chatId: chatId,
      senderId: 'admin', // Use senderId field (per admin guide)
      text: text,
      timestamp: DateTime.now(),
      type: MessageType.text,
      status: MessageStatus.sending,
      replyToId: replyToId,
      metadata: metadata,
    );

    // Add message to Firestore with timestamp field (matches database structure)
    final messageJson = message.toJson();
    // Ensure timestamp is set using server timestamp
    messageJson['timestamp'] = FieldValue.serverTimestamp();
    // Also keep createdAt for backward compatibility
    messageJson['createdAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(messageJson);

    // Update chat's last message
    await _firestore
        .collection('chats')
        .doc(chatId)
        .update({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((e) => Logger.error('Error updating chat last message', e));

    // Update message status to sent
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'status': MessageStatus.sent.name});

    // Send push notification to other participants
    await _sendPushNotification(chatId, text);
  }

  /// Send an image message to a user (per admin guide: chats/{chatId}/messages)
  Future<void> sendImageMessageToUser({
    required String userId,
    required File imageFile,
    String? caption,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    // Get or create chat thread
    final chatId = await getOrCreateChatWithUser(userId);

    final messageId = _uuid.v4();

    // Upload image to Cloudinary
    final downloadUrl = await _cloudinaryService.uploadImageWithPublicId(
      imageFile: imageFile,
      publicId: 'chat_images/$chatId/$messageId',
      folder: 'chat_images',
    );

    if (downloadUrl == null) {
      throw Exception('Failed to upload image to Cloudinary');
    }

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    // Create message document with senderId field (per admin guide)
    await messageRef.set({
      'senderId': 'admin', // Use senderId field (per admin guide)
      'text': caption ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'image',
      'status': MessageStatus.sent.name,
      'chatId': chatId,
      'attachments': [
        {
          'type': 'image',
          'url': downloadUrl,
          'name': 'image.jpg',
          'size': await imageFile.length(),
          'mimeType': 'image/jpeg',
        },
      ],
      if (metadata != null) 'metadata': metadata,
    });

    // Update chat document metadata (per admin guide)
    final lastMessage = caption ?? '📷 Image';
    final lastMessagePreview =
        lastMessage.length > 100 ? lastMessage.substring(0, 100) : lastMessage;
    await _firestore
        .collection('chats')
        .doc(chatId)
        .update({
          'lastMessage': lastMessagePreview,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount.$userId': FieldValue.increment(
            1,
          ), // Increment user's unread count
        })
        .catchError((e) => Logger.error('Error updating chat metadata', e));

    // Send push notification
    await _sendPushNotificationToUser(userId, lastMessage, isImage: true);
  }

  /// Send an image message (legacy method - keeps backward compatibility)
  Future<void> sendImageMessage({
    required String chatId,
    required File imageFile,
    String? caption,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    // Try to extract userId from chat
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData?['participants'] ?? []);
        final userId = participants.firstWhere(
          (id) => id != 'admin' && id != _currentUser!.id,
          orElse: () => '',
        );
        if (userId.isNotEmpty) {
          // Use new structure
          await sendImageMessageToUser(
            userId: userId,
            imageFile: imageFile,
            caption: caption,
            metadata: metadata,
          );
          return;
        }
      }
    } catch (e) {
      Logger.error('Error getting chat data, using old structure', e);
    }

    // Fallback to old structure (backward compatibility)
    final messageId = _uuid.v4();

    // Upload image to Cloudinary
    final downloadUrl = await _cloudinaryService.uploadImageWithPublicId(
      imageFile: imageFile,
      publicId: 'chat_images/$chatId/$messageId',
      folder: 'chat_images',
    );

    if (downloadUrl == null) {
      throw Exception('Failed to upload image to Cloudinary');
    }

    // Create attachment with correct structure: {type: "image", url: "...", name: "..."}
    final attachment = MessageAttachment(
      name: 'image.jpg',
      url: downloadUrl,
      size: await imageFile.length(),
      mimeType: 'image/jpeg',
      type: 'image', // Match database structure
    );

    final message = FirebaseChatMessage(
      id: messageId,
      chatId: chatId,
      senderId: 'admin', // Use senderId field (per admin guide)
      text: caption ?? '',
      timestamp: DateTime.now(),
      type: MessageType.image,
      status: MessageStatus.sent,
      metadata: metadata,
      attachments: [attachment],
    );

    // Add message to Firestore with timestamp field (matches database structure)
    final messageJson = message.toJson();
    // Ensure timestamp is set using server timestamp
    messageJson['timestamp'] = FieldValue.serverTimestamp();
    // Also keep createdAt for backward compatibility
    messageJson['createdAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(messageJson);

    // Update chat's last message
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': caption ?? '📷 Image',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Send push notification
    await _sendPushNotification(chatId, caption ?? 'Image', isImage: true);
  }

  /// Send a file message
  Future<void> sendFileMessage({
    required String chatId,
    required File file,
    required String fileName,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    final messageId = _uuid.v4();

    // Upload file to Firebase Storage
    final storageRef = _storage
        .ref()
        .child('chat_files')
        .child(chatId)
        .child('$messageId-$fileName');

    final uploadTask = await storageRef.putFile(file);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    final attachment = MessageAttachment(
      name: fileName,
      url: downloadUrl,
      size: await file.length(),
      mimeType: _getMimeType(fileName),
    );

    final message = FirebaseChatMessage(
      id: messageId,
      chatId: chatId,
      senderId: 'admin', // Use senderId field (per admin guide)
      text: fileName,
      timestamp: DateTime.now(),
      type: MessageType.file,
      status: MessageStatus.sent,
      metadata: metadata,
      attachments: [attachment],
    );

    // Add message to Firestore
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(message.toJson());

    // Update chat's last message
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': fileName,
      'lastMessageTime': Timestamp.fromDate(DateTime.now()),
    });

    // Send push notification
    await _sendPushNotification(chatId, 'File: $fileName');
  }

  /// Create a new chat
  Future<String> createChat({
    required String userId,
    String? subject,
    ChatPriority priority = ChatPriority.normal,
  }) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    final chatId = _uuid.v4();
    // Include 'admin' string in participants array (matches database structure)
    // Also include admin user ID for compatibility
    final participants = <String>[userId];
    if (_currentUser!.role == 'admin') {
      participants.add('admin');
      if (!participants.contains(_currentUser!.id)) {
        participants.add(_currentUser!.id);
      }
    } else {
      participants.add(_currentUser!.id);
    }

    final chat = FirebaseChat(
      id: chatId,
      participants: participants,
      lastMessageTime: DateTime.now(),
      createdAt: DateTime.now(),
      unreadCount: {},
      subject: subject,
      status: ChatStatus.active,
      priority: priority,
      assignedAdminId: _currentUser!.role == 'admin' ? _currentUser!.id : null,
    );

    await _firestore.collection('chats').doc(chatId).set(chat.toJson());
    Logger.info(
      'Created new chat: $chatId with participants: ${participants.join(", ")}',
    );
    return chatId;
  }

  /// Update chat status
  Future<void> updateChatStatus(String chatId, ChatStatus status) async {
    await _firestore.collection('chats').doc(chatId).update({
      'status': status.name,
    });
  }

  /// Update chat priority
  Future<void> updateChatPriority(String chatId, ChatPriority priority) async {
    await _firestore.collection('chats').doc(chatId).update({
      'priority': priority.name,
    });
  }

  /// Assign chat to admin
  Future<void> assignChatToAdmin(String chatId, String adminId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'assignedAdminId': adminId,
    });
  }

  /// Mark messages as seen by current user
  Future<void> _markMessagesAsSeen(
    String chatId,
    List<FirebaseChatMessage> messages,
  ) async {
    if (_currentUser == null) return;

    final batch = _firestore.batch();

    for (final message in messages) {
      if (message.senderId != _currentUser!.id &&
          message.status != MessageStatus.seen) {
        final messageRef = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(message.id);

        batch.update(messageRef, {'status': MessageStatus.seen.name});
      }
    }

    // Reset unread count for current user
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {'unreadCount.${_currentUser!.id}': 0});

    await batch.commit();
  }

  /// Mark messages as seen for chat (per admin guide structure)
  Future<void> _markChatMessagesAsSeen(
    String chatId,
    List<FirebaseChatMessage> messages,
  ) async {
    if (_currentUser == null) return;

    // Reset unread count for admin in chat document
    await _firestore
        .collection('chats')
        .doc(chatId)
        .update({'unreadCount.admin': 0})
        .catchError((e) => Logger.error('Error resetting unread count', e));
  }

  /// Send push notification to a specific user
  Future<void> _sendPushNotificationToUser(
    String userId,
    String message, {
    bool isImage = false,
  }) async {
    try {
      // Get user's OneSignal player ID using service method (checks both Firestore and Realtime DB)
      final playerId = await _oneSignalService.getPlayerIdForUser(userId);
      if (playerId == null) {
        Logger.debug('No OneSignal player ID for user $userId');
        return;
      }

      // Get sender name
      final senderName = _currentUser?.name ?? 'Admin';

      // Send notification via OneSignal
      await _oneSignalService.sendNotificationToUser(
        playerId: playerId,
        title: senderName,
        body: isImage ? 'Sent an image' : message,
        data: {'userId': userId, 'type': isImage ? 'image' : 'text'},
      );
    } catch (e) {
      Logger.error('Error sending push notification to user', e);
    }
  }

  Future<void> _sendPushNotification(
    String chatId,
    String message, {
    bool isImage = false,
  }) async {
    try {
      // Get chat participants
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chat = FirebaseChat.fromJson({
        'id': chatDoc.id,
        ...chatDoc.data()!,
      });

      // Get OneSignal player IDs for other participants
      final otherParticipants =
          chat.participants.where((id) => id != _currentUser?.id).toList();

      final playerIds = <String>[];

      for (final participantId in otherParticipants) {
        final playerId = await _oneSignalService.getPlayerIdForUser(
          participantId,
        );
        if (playerId != null) {
          playerIds.add(playerId);
        }
      }

      if (playerIds.isEmpty) {
        Logger.debug('No OneSignal player IDs found for participants');
        return;
      }

      // Get sender name
      final senderName = _currentUser?.name ?? 'Admin';

      // Send notification via OneSignal
      await _oneSignalService.sendNotificationToUsers(
        playerIds: playerIds,
        title: senderName,
        body: isImage ? 'Sent an image' : message,
        data: {'chatId': chatId, 'type': isImage ? 'image' : 'text'},
      );
    } catch (e) {
      Logger.error('Error sending push notification', e);
    }
  }

  /// Get user by ID
  Future<FirebaseUser?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return FirebaseUser.fromJson({'id': doc.id, ...doc.data()!});
      }
    } catch (e) {
      Logger.error('Error getting user', e);
    }
    return null;
  }

  /// Enrich user data from Realtime DB when Firestore data is missing
  Future<FirebaseUser> _enrichUserFromRealtimeDB(
    String userId,
    FirebaseUser user,
  ) async {
    // If user already has name and email, return as-is
    if (user.name.isNotEmpty &&
        user.name != 'Unknown User' &&
        user.email.isNotEmpty) {
      return user;
    }

    // Fetch from Realtime DB
    try {
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          // Extract name fields
          final firstName = data['firstName']?.toString() ?? '';
          final middleName = data['middleName']?.toString() ?? '';
          final lastName = data['lastName']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';

          // Combine name parts
          final nameParts = <String>[];
          if (firstName.trim().isNotEmpty) nameParts.add(firstName.trim());
          if (middleName.trim().isNotEmpty) nameParts.add(middleName.trim());
          if (lastName.trim().isNotEmpty) nameParts.add(lastName.trim());
          final fullName =
              nameParts.isNotEmpty
                  ? nameParts.join(' ')
                  : (email.isNotEmpty ? email.split('@').first : user.name);

          // Parse dates if needed
          DateTime? createdAt = user.createdAt;
          DateTime? lastSeen = user.lastSeen;

          if (data['createdAt'] != null) {
            try {
              final createdAtValue = data['createdAt'];
              if (createdAtValue is int) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
              } else if (createdAtValue is String) {
                createdAt = DateTime.parse(createdAtValue);
              }
            } catch (e) {
              Logger.debug('Error parsing createdAt for user $userId: $e');
            }
          }

          if (data['lastSeen'] != null) {
            try {
              final lastSeenValue = data['lastSeen'];
              if (lastSeenValue is int) {
                lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenValue);
              } else if (lastSeenValue is String) {
                lastSeen = DateTime.parse(lastSeenValue);
              }
            } catch (e) {
              Logger.debug('Error parsing lastSeen for user $userId: $e');
            }
          }

          // Check online status from presence
          bool isOnline = user.isOnline;
          if (data['presence'] is Map) {
            final presence = data['presence'] as Map;
            isOnline = presence['isOnline'] == true;
          }

          // Return enriched user
          return user.copyWith(
            name: fullName.isNotEmpty ? fullName : user.name,
            email: email.isNotEmpty ? email : user.email,
            photoUrl: data['photoUrl']?.toString() ?? user.photoUrl,
            createdAt: createdAt ?? user.createdAt,
            lastSeen: lastSeen ?? user.lastSeen,
            isOnline: isOnline,
          );
        }
      }
    } catch (e) {
      Logger.error('Error enriching user $userId from Realtime DB: $e');
    }

    return user; // Return original if enrichment fails
  }

  /// Get all users from Firestore (excluding admin users) with periodic refresh
  Stream<List<FirebaseUser>> getAllUsersStream() {
    _usersStreamController ??= StreamController<List<FirebaseUser>>.broadcast(
      onListen: () {
        Logger.debug(
          '[UsersStream] Listener added, starting Firestore listener',
        );
        _startUsersListener();
      },
      onCancel: () {
        if (!(_usersStreamController?.hasListener ?? false)) {
          Logger.debug(
            '[UsersStream] No listeners, stopping Firestore listener',
          );
          _stopUsersListener();
        }
      },
    );

    return _usersStreamController!.stream;
  }

  /// Get all users (one-time fetch) with Realtime DB enrichment
  Future<List<FirebaseUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return await _buildUsersFromDocs(snapshot.docs);
    } catch (e) {
      Logger.error('Error getting all users', e);
      return [];
    }
  }

  /// Get or create chat with a user (per admin guide structure)
  /// Always ensures chat thread exists in chats collection
  Future<String> getOrCreateChatWithUser(String userId) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    // Search for existing chat thread - try multiple strategies
    try {
      // Strategy 1: Search for chats with 'admin' string
      final existingChatsWithAdmin =
          await _firestore
              .collection('chats')
              .where('participants', arrayContains: 'admin')
              .get();

      for (final doc in existingChatsWithAdmin.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        // Check if both userId and 'admin' are in participants
        if (participants.contains(userId) && participants.contains('admin')) {
          Logger.debug(
            'Found existing chat thread with "admin" string: ${doc.id}',
          );

          // Optional: Update chat to include admin UID if missing (for consistency)
          if (!participants.contains(_currentUser!.id)) {
            try {
              await _firestore.collection('chats').doc(doc.id).update({
                'participants': FieldValue.arrayUnion([_currentUser!.id]),
              });
              Logger.debug('Updated chat to include admin UID');
            } catch (e) {
              Logger.error('Error updating chat participants', e);
            }
          }

          return doc.id;
        }
      }

      // Strategy 2: If admin, search for chats with admin UID (fallback for existing chats)
      if (_currentUser!.role == 'admin') {
        Logger.debug(
          'No chat found with "admin" string, trying search with admin UID: ${_currentUser!.id}',
        );
        final existingChatsWithUid =
            await _firestore
                .collection('chats')
                .where('participants', arrayContains: _currentUser!.id)
                .get();

        for (final doc in existingChatsWithUid.docs) {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);
          // Check if both userId and admin UID are in participants
          if (participants.contains(userId) &&
              participants.contains(_currentUser!.id)) {
            Logger.debug(
              'Found existing chat thread with admin UID: ${doc.id}',
            );

            // Update chat to include 'admin' string for future queries (migration)
            if (!participants.contains('admin')) {
              try {
                await _firestore.collection('chats').doc(doc.id).update({
                  'participants': FieldValue.arrayUnion(['admin']),
                });
                Logger.debug(
                  'Updated chat to include "admin" string for consistency',
                );
              } catch (e) {
                Logger.error('Error updating chat with "admin" string', e);
              }
            }

            return doc.id;
          }
        }
      }
    } catch (e) {
      Logger.error('Error checking for existing chat', e);
    }

    // Create new chat thread if none exists
    Logger.info('Creating new chat thread for user: $userId');
    return await createChat(userId: userId);
  }

  /// Diagnostic method to check admin status and chat visibility
  Future<void> debugAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      Logger.warning('No authenticated user');
      return;
    }

    Logger.debug('=== Admin Status Debug ===');
    Logger.debug('Firebase Auth UID: ${user.uid}');
    Logger.debug('Firebase Auth Email: ${user.email}');

    // Check users collection
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      Logger.debug('Found in users collection');
      Logger.debug('Role: ${data?['role']}');
      Logger.debug('Name: ${data?['name']}');
      Logger.debug('Email: ${data?['email']}');
    } else {
      Logger.debug('NOT found in users collection');
    }

    // Check admins collection
    final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
    if (adminDoc.exists) {
      final data = adminDoc.data();
      Logger.debug('Found in admins collection');
      Logger.debug('Role: ${data?['role']}');
      Logger.debug('Name: ${data?['name']}');
      Logger.debug('Email: ${data?['email']}');
    } else {
      Logger.debug('NOT found in admins collection');
    }

    Logger.debug('Current User Object: ${_currentUser?.toJson()}');
    Logger.debug('Current User Role: ${_currentUser?.role}');
    Logger.debug('Current User ID: ${_currentUser?.id}');

    // Check sample chats
    try {
      final sampleChats = await _firestore.collection('chats').limit(3).get();

      Logger.debug('Sample chats in database: ${sampleChats.docs.length}');
      for (final doc in sampleChats.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        Logger.debug('Chat ${doc.id} participants: ${participants.join(", ")}');
        Logger.debug('  Contains "admin": ${participants.contains("admin")}');
        Logger.debug(
          '  Contains admin UID: ${participants.contains(user.uid)}',
        );
      }
    } catch (e) {
      Logger.error('Error checking sample chats', e);
    }

    Logger.debug('========================');
  }

  /// Get current user
  FirebaseUser? get currentUser => _currentUser;

  /// Get MIME type from file extension
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Dispose resources
  void dispose() {
    _isListeningToChats = false;
    _stopUsersListener();
    _usersStreamController?.close();
    _usersStreamController = null;
    _usersSnapshotSubscription?.cancel();
    _usersSnapshotSubscription = null;
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _chatsController.close();
    _messagesController.close();
    _statisticsController.close();
  }

  void _startUsersListener() {
    if (_usersSnapshotSubscription != null) return;

    _usersSnapshotSubscription = _firestore
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) async {
            await _handleUsersSnapshot(snapshot.docs);
          },
          onError: (error, stackTrace) {
            Logger.error(
              '[UsersStream] Error listening to users snapshot',
              error,
              stackTrace,
            );
            if (_usersStreamController != null &&
                !_usersStreamController!.isClosed) {
              _usersStreamController!.addError(error, stackTrace);
            }
          },
        );

    Logger.debug('[UsersStream] Firestore listener started');
  }

  void _stopUsersListener() {
    _usersSnapshotSubscription?.cancel();
    _usersSnapshotSubscription = null;
    Logger.debug('[UsersStream] Firestore listener stopped');
  }

  Future<void> _handleUsersSnapshot(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_usersStreamController == null || _usersStreamController!.isClosed) {
      return;
    }

    try {
      final users = await _buildUsersFromDocs(docs);
      _usersStreamController?.add(List<FirebaseUser>.unmodifiable(users));
      Logger.debug('[UsersStream] Emitted ${users.length} users from snapshot');
    } catch (e, stackTrace) {
      Logger.error(
        '[UsersStream] Error processing users snapshot',
        e,
        stackTrace,
      );
      if (_usersStreamController != null && !_usersStreamController!.isClosed) {
        _usersStreamController!.addError(e, stackTrace);
      }
    }
  }

  Future<List<FirebaseUser>> _buildUsersFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final users = <FirebaseUser>[];

    for (final doc in docs) {
      final user = await _parseUserDocument(doc);
      if (user != null) {
        users.add(user);
      }
    }

    users.sort((a, b) => b.activityTimestamp.compareTo(a.activityTimestamp));
    return users;
  }

  Future<FirebaseUser?> _parseUserDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final map = Map<String, dynamic>.from(doc.data());
    final role = map['role']?.toString().toLowerCase();
    if (role == 'admin') {
      return null;
    }

    try {
      final user = FirebaseUser.fromJson({'id': doc.id, ...map});
      return await _enrichUserFromRealtimeDB(doc.id, user);
    } catch (e, stackTrace) {
      Logger.error('Error parsing user ${doc.id}', e, stackTrace);
      return null;
    }
  }
}

/// Extension to convert Firebase models to flutter_chat_types
extension FirebaseChatExtensions on FirebaseChat {
  /// Get other participant (non-admin user)
  String? getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}
