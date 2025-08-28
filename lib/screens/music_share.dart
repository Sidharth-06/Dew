import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dew/main.dart'; // audioHandler
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'; // new for spring simulation
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:shared_preferences/shared_preferences.dart';

class MusicSharePage extends StatefulWidget {
  final MediaItem metadata;
  const MusicSharePage({Key? key, required this.metadata}) : super(key: key);

  @override
  State<MusicSharePage> createState() => _MusicSharePageState();
}

class _MusicSharePageState extends State<MusicSharePage>
    with TickerProviderStateMixin {
  final _fire = FirebaseFirestore.instance;
  String? _deviceId;
  String? _transferId;
  bool _creating = false;
  bool _listening = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _nfcAvailable = false;
  bool _writingNfc = false;
  Offset _dragOffset = Offset.zero;
  final GlobalKey _stackKey = GlobalKey();
  AnimationController? _throwController;
  Animation<Offset>? _throwAnim;
  double _lastThrowAngle = 0.0;

  // NEW: long press lock + hover state for desktop
  bool _longPressing = false;
  bool _hovering = false;

  late AnimationController _returnController; // NEW
  Animation<Offset>? _returnAnimation; // NEW

  @override
  void initState() {
    super.initState();
    _initializeAsync();
    _throwController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _returnController = AnimationController.unbounded(vsync: this);
  }

  Future<void> _initializeAsync() async {
    await _initDeviceId();
    await _checkNfcAvailable();
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('deviceId') ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString('deviceId', _deviceId!);
    if (mounted) setState(() {});
  }

  Future<void> _checkNfcAvailable() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      if (mounted) {
        setState(() {
          _nfcAvailable = availability != NFCAvailability.not_supported &&
              availability != NFCAvailability.disabled;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> _createTransferDoc() async {
    final payload = {
      'metadata': {
        'ytid': widget.metadata.extras?['ytid'] ?? widget.metadata.id,
        'title': widget.metadata.title,
        'artist': widget.metadata.artist ?? '',
        'image': widget.metadata.artUri?.toString() ?? '',
        'duration': widget.metadata.duration?.inMilliseconds ?? 0,
      },
      'senderDevice': _deviceId,
      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
    };
    return await _fire.collection('music_transfers').add(payload);
  }

  Future<void> _writeNfc(String transferId) async {
    setState(() => _writingNfc = true);
    try {
      final tag = await FlutterNfcKit.poll(
          timeout: const Duration(seconds: 15),
          iosMultipleTagMessage: "Multiple tags found!",
          iosAlertMessage: "Hold device near target");
      final uri = 'dew://transfer/$transferId';
      final ndefRec = ndef.UriRecord.fromString(uri);
      await FlutterNfcKit.writeNDEFRecords([ndefRec]);
      await FlutterNfcKit.finish(iosAlertMessage: 'Transfer written');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NFC write successful')));
      }
    } catch (e) {
      debugPrint('NFC write failed: $e');
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('NFC write failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _writingNfc = false);
    }
  }

  Future<dynamic> _readNfc() async {
    try {
      final tag = await FlutterNfcKit.poll(
          timeout: const Duration(seconds: 20),
          iosMultipleTagMessage: "Multiple tags found!");

      if (tag.ndefAvailable == true) {
        final records = await FlutterNfcKit.readNDEFRecords(cached: false);
        await FlutterNfcKit.finish();
        if (records.isNotEmpty) {
          final rec = records.first;
          try {
            final rawPayload = rec.payload;
            final payloadStr = utf8.decode(rawPayload ?? []);
            if (payloadStr.isNotEmpty) {
              if (payloadStr.startsWith('dew://transfer/')) {
                return payloadStr.split('dew://transfer/').last;
              }
              return payloadStr;
            }
          } catch (_) {}
          final txt = rec.toString();

          if (txt.contains('dew://transfer/')) {
            final parts = txt.split('dew://transfer/');
            if (parts.length > 1) {
              final id = parts.join().split(RegExp(r'[^A-Za-z0-9_\-]')).first;
              return id;
            }
          }
        }
      } else {
        await FlutterNfcKit.finish();
      }
    } catch (e) {
      debugPrint('NFC read failed: $e');
      try {
        await FlutterNfcKit.finish();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('NFC read failed: $e')));
      }
    }
    return null;
  }

  Future<void> _sendWithThrow() async {
    if (_creating) return;
    if (_longPressing) return; // respect long-press lock
    setState(() => _creating = true);

    final docRef = await _createTransferDoc();
    _transferId = docRef.id;

    final random = Random();
    final angle = (random.nextDouble() * 0.6) - 0.3;
    _lastThrowAngle = angle;

    final targetDx = 2.0 * (angle == 0 ? 1 : angle.sign);
    final targetDy = -1.4;
    _throwAnim = Tween<Offset>(
            begin: Offset.zero, end: Offset(targetDx, targetDy))
        .animate(
            CurvedAnimation(parent: _throwController!, curve: Curves.easeIn));
    _throwController!.forward();

    await Future.delayed(const Duration(milliseconds: 420));
    await docRef.update({
      'status': 'thrown',
      'transferId': _transferId,
      'throwVector': {'dx': targetDx, 'dy': targetDy, 'angle': angle},
      'thrownAt': FieldValue.serverTimestamp(),
    });

    if (_nfcAvailable) {
      try {
        await _writeNfc(_transferId!);
      } catch (e) {
        debugPrint('NFC write error: $e');
      }
    }

    if (mounted) setState(() => _creating = false);
  }

  Future<void> _startListeningForIncoming({String? manualId}) async {
    if (_listening) return;
    await _sub?.cancel();
    setState(() => _listening = true);

    if (manualId != null) {
      _sub = _fire
          .collection('music_transfers')
          .doc(manualId)
          .snapshots()
          .listen((snap) {
        if (snap.exists) _onIncomingTransferDoc(snap);
      }, onError: (e) {
        if (mounted) setState(() => _listening = false);
      });
      return;
    }

    final query = _fire
        .collection('music_transfers')
        .where('status', isEqualTo: 'thrown')
        .orderBy('thrownAt', descending: true)
        .limit(5);

    _sub = query.snapshots().listen((snap) {
      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['senderDevice'] != _deviceId) {
          _onIncomingTransferDoc(doc);
          break;
        }
      }
    }, onError: (e) {
      if (mounted) setState(() => _listening = false);
    }) as StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?;
  }

  Future<void> _onIncomingTransferDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    final meta = data['metadata'] as Map<String, dynamic>?;
    final throwVector = (data['throwVector'] as Map<String, dynamic>?) ?? {};

    if (meta == null) return;

    final startOffset = Offset(
      throwVector['dx'] != null ? -(throwVector['dx']) : -1.2,
      throwVector['dy'] ?? 0.0,
    );

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IncomingCardDialog(
        title: meta['title'] ?? '',
        artist: meta['artist'] ?? '',
        imageUrl: meta['image'] ?? '',
        startOffset: startOffset,
      ),
    );

    if (accepted == true) {
      await doc.reference.update({
        'status': 'received',
        'receiverDevice': _deviceId,
        'receivedAt': FieldValue.serverTimestamp(),
      });

      final songDetails = {
        'ytid': meta['ytid'] ?? '',
        'title': meta['title'] ?? '',
        'artist': meta['artist'] ?? '',
        'image': meta['image'] ?? '',
        'duration': Duration(milliseconds: meta['duration'] ?? 0),
      };

      try {
        await audioHandler.playSong(songDetails);
      } catch (e) {
        debugPrint('Error playing shared song: $e');
      }
    }

    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _listening = false);
  }

  // NEW: start a spring animation back to zero
  void _startReturnAnimation(double velocity) {
    final spring = SpringDescription(mass: 1, stiffness: 200, damping: 25);
    final sim = SpringSimulation(
      spring,
      1, // start at full animation (fraction=1)
      0, // end at zero
      velocity / (MediaQuery.of(context).size.height),
    );
    _returnController.animateWith(sim).then((_) {
      if (mounted) {
        setState(() {
          // lerp from current dragOffset toward zero
          _dragOffset =
              Offset.lerp(_dragOffset, Offset.zero, _returnController.value)!;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _throwController?.dispose();
    _returnController.dispose();
    super.dispose();
  }

  // Helper: obtain current Stack/render bounds used for clamping
  Size _getStackSize() {
    try {
      final ctx = _stackKey.currentContext;
      if (ctx == null) return MediaQuery.of(context).size;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null || !rb.hasSize) return MediaQuery.of(context).size;
      return rb.size;
    } catch (_) {
      return MediaQuery.of(context).size;
    }
  }

  // Helper: clamp an offset to avoid huge pixel overshoot
  // Accepts container bounds and optional child size so clamping keeps the card within visible area.
  Offset _clampOffset(Offset o, Size container,
      {Size? childSize, double maxFactor = 1.6}) {
    final cw = childSize?.width ?? 0.0;
    final ch = childSize?.height ?? 0.0;

    // Allow some horizontal room but prevent insane values
    final maxDx = max(20.0,
        ((container.width - cw).clamp(0.0, container.width)).toDouble() * (maxFactor * 0.5));
    // Upward throw may go off-screen visually, allow limited overshoot based on card height
    final maxUp = max(40.0, ch * 1.2);
    // Prevent going below container bottom (leave small margin)
    final maxDown = max(0.0, (container.height - ch - 16.0));

    final dx = o.dx.clamp(-maxDx, maxDx);
    final dy = o.dy.clamp(-maxUp, maxDown);

    return Offset(dx, dy);
  }

  // ENHANCED UI: Big card, gradient, image cover, rotation on drag, long-press lock
  Widget _buildDraggableCard() {
    final meta = widget.metadata;
    final screen = MediaQuery.of(context).size;
    // card size responsive to screen, capped
    final double width = min(screen.width * 0.72, 480.0).toDouble();
    final double height = width * 0.62;
    final stackSize = _getStackSize();

    return MouseRegion(
      cursor: _hovering ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onLongPressStart: (_) {
          // lock the card when user long-presses (it should never go anywhere)
          setState(() {
            _longPressing = true;
            _throwController?.reset();
            _dragOffset = Offset.zero;
          });
        },
        onLongPressEnd: (_) {
          // release lock on long-press end
          setState(() {
            _longPressing = false;
            _dragOffset = Offset.zero;
          });
        },
        onPanStart: (details) {
          if (_longPressing) return;
          _throwController?.reset();
          setState(() {
            _dragOffset = Offset.zero;
          });
        },
        onPanUpdate: (details) {
          if (_longPressing) return;
          setState(() {
            // restrict drag per frame a bit so user can't fling to insane numbers quickly
            final tentative = _dragOffset + details.delta;
            _dragOffset = _clampOffset(tentative, stackSize,
                childSize: Size(width, height), maxFactor: 1.6);
          });
        },
        onPanEnd: (details) async {
          if (_longPressing) return;
          final velocity = details.velocity.pixelsPerSecond;
          final upward = velocity.dy < -300 || _dragOffset.dy < -height * 0.25;
          if (upward) {
            await _sendWithThrow();
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) {
              setState(() {
                _dragOffset = Offset.zero;
                _throwController?.reset();
              });
            }
          } else {
            // pass vertical velocity so the spring reacts
            _startReturnAnimation(velocity.dy);
          }
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_throwController!, _returnController]),
          builder: (ctx, child) {
            // combine throw + return, then clamp
            final throwOff = _throwAnim?.value ?? Offset.zero;
            final returnOff = _returnAnimation?.value ?? Offset.zero;
            final raw = _dragOffset + throwOff + returnOff;
            final clamped = _clampOffset(raw, _getStackSize(),
                childSize: Size(width, height), maxFactor: 1.6);
            final rot =
                (clamped.dx / max(1, width)) * 0.12 + (_lastThrowAngle * 0.12);
            final scale = _hovering ? 1.02 : 1.0;
            return Transform.translate(
              offset: clamped,
              child: Transform.rotate(
                angle: rot,
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceVariant,
                  Theme.of(context).colorScheme.surface
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Artwork cover
                  if (meta.artUri != null)
                    Image.network(
                      meta.artUri!.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade900),
                    )
                  else
                    Container(color: Colors.grey.shade800),
                  // overlay gradient to ensure text legibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.28),
                          Colors.black.withOpacity(0.46),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // card content
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // small chip indicating share mode
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send,
                                    size: 14, color: Colors.white70),
                                const SizedBox(width: 8),
                                Text('Share',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // title + artist
                          Text(
                            meta.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          // big throw hint bar
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _longPressing
                                          ? 'Holding — locked'
                                          : 'Drag up to throw • long-press to lock',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // small glowing indicator
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.36),
                                        blurRadius: 14,
                                        spreadRadius: 1)
                                  ],
                                ),
                                child: const Icon(Icons.arrow_upward,
                                    color: Colors.white),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Improved bottom control bar UI: compact, grouped, responsive, with tooltips.
  Widget _buildControls() {
    final theme = Theme.of(context);
    final btnStyle = ElevatedButton.styleFrom(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    final children = <Widget>[
      Tooltip(
          message: 'Create transfer and throw',
          child: ElevatedButton.icon(
            style: btnStyle,
            onPressed: _creating ? null : _sendWithThrow,
            icon: const Icon(Icons.send),
            label: const Text('Throw'),
          )),
      Tooltip(
          message: 'Write transfer id to NFC tag/peer',
          child: ElevatedButton.icon(
            style: btnStyle,
            onPressed: (!_nfcAvailable || _transferId == null || _writingNfc)
                ? null
                : () async {
                    try {
                      await _writeNfc(_transferId!);
                    } catch (_) {}
                  },
            icon: const Icon(Icons.nfc),
            label: Text(_nfcAvailable ? 'NFC' : 'NFC ● off'),
          )),
      Tooltip(
          message: 'Listen for incoming transfers',
          child: ElevatedButton.icon(
            style: btnStyle,
            onPressed: _listening
                ? null
                : () async {
                    await _startListeningForIncoming();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Listening for transfers…')));
                  },
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Listen'),
          )),
      Tooltip(
          message: 'Read transfer code via NFC',
          child: ElevatedButton.icon(
            style: btnStyle,
            onPressed: _listening
                ? null
                : () async {
                    final id = await _readNfc();
                    if (id != null) {
                      await _startListeningForIncoming(manualId: id);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Transfer read via NFC')));
                    } else {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No NFC transfer read')));
                    }
                  },
            icon: const Icon(Icons.search),
            label: const Text('Read'),
          )),
      Tooltip(
          message: 'Enter transfer code manually',
          child: ElevatedButton.icon(
            style: btnStyle,
            onPressed: () async {
              final id = await showDialog<String?>(
                context: context,
                builder: (ctx) {
                  final ctrl = TextEditingController();
                  return AlertDialog(
                    title: const Text('Enter Transfer ID'),
                    content: TextField(
                        controller: ctrl,
                        decoration:
                            const InputDecoration(hintText: 'Transfer ID')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                          child: const Text('OK')),
                    ],
                  );
                },
              );
              if (id != null && id.isNotEmpty)
                await _startListeningForIncoming(manualId: id);
            },
            icon: const Icon(Icons.keyboard),
            label: const Text('Manual'),
          )),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: children
              .map((w) =>
                  Padding(padding: const EdgeInsets.only(right: 10), child: w))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Song')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Drag up on the card to throw it to a nearby device.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                key: _stackKey,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(top: 8, child: _buildDraggableCard()),
                  Positioned(
                    right: 20,
                    top: 8,
                    child: Column(
                      children: [
                        Icon(Icons.wifi,
                            color: theme.colorScheme.primary, size: 28),
                        Text('Nearby', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildControls(),
            const SizedBox(height: 12),
            if (_transferId != null)
              SelectableText('Transfer ID: $_transferId'),
          ],
        ),
      ),
    );
  }
}

// IncomingCardDialog unchanged except it supports startOffset param
class IncomingCardDialog extends StatefulWidget {
  final String title;
  final String artist;
  final String imageUrl;
  final Offset? startOffset;

  const IncomingCardDialog({
    Key? key,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.startOffset,
  }) : super(key: key);

  @override
  State<IncomingCardDialog> createState() => _IncomingCardDialogState();
}

class _IncomingCardDialogState extends State<IncomingCardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    final begin = widget.startOffset ?? const Offset(-1.2, 0.0);
    _offset = Tween<Offset>(begin: begin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SlideTransition(
        position: _offset,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: widget.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(widget.imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.music_note)),
                        )
                      : const Icon(Icons.music_note, size: 48),
                  title: Text(widget.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(widget.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Decline')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        // ignore: require_trailing_commas
                        child: const Text('Accept & Play')),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
