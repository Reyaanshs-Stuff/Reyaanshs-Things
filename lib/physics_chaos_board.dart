import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PhysicsElement {
  const PhysicsElement({
    required this.id,
    required this.size,
    required this.builder,
  });

  final String id;
  final Size size;
  final Widget Function(Key key) builder;
}

class PhysicsChaosBoard extends StatefulWidget {
  const PhysicsChaosBoard({required this.elements, super.key});

  final List<PhysicsElement> elements;

  @override
  State<PhysicsChaosBoard> createState() => _PhysicsChaosBoardState();
}

class _PhysicsChaosBoardState extends State<PhysicsChaosBoard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Size _boardSize = Size.zero;
  Duration? _lastFrame;
  List<_PhysicsBody> _bodies = [];
  final _random = math.Random();
  int _nextSpawnId = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_step)..start();
  }

  void _step(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;
    if (previous == null || _bodies.isEmpty) return;

    final delta = ((elapsed - previous).inMicroseconds / 1000000)
        .clamp(0.0, 0.04)
        .toDouble();
    if (delta == 0) return;

    setState(() {
      for (final body in _bodies) {
        if (body.isDragging) continue;

        body.velocity += Offset(0, 680 * delta);
        body.position += body.velocity * delta;
        body.angle += body.angularVelocity * delta;
        _bounceOffWalls(body);
      }

      _resolveCollisions();
      for (final body in _bodies) {
        _bounceOffWalls(body);
      }
    });
  }

  void _bounceOffWalls(_PhysicsBody body) {
    final maxX = math.max(0.0, _boardSize.width - body.size.width).toDouble();
    final maxY = math.max(0.0, _boardSize.height - body.size.height).toDouble();

    if (body.position.dx < 0) {
      body.position = Offset.zero + Offset(0, body.position.dy);
      body.velocity = Offset(body.velocity.dx.abs() * 0.72, body.velocity.dy);
      body.angularVelocity += 0.25;
    } else if (body.position.dx > maxX) {
      body.position = Offset(maxX, body.position.dy);
      body.velocity = Offset(-body.velocity.dx.abs() * 0.72, body.velocity.dy);
      body.angularVelocity -= 0.25;
    }

    if (body.position.dy < 0) {
      body.position = Offset(body.position.dx, 0);
      body.velocity = Offset(body.velocity.dx, body.velocity.dy.abs() * 0.55);
    } else if (body.position.dy > maxY) {
      body.position = Offset(body.position.dx, maxY);
      body.velocity = Offset(
        body.velocity.dx * 0.88,
        body.velocity.dy.abs() > 90 ? -body.velocity.dy.abs() * 0.62 : 0,
      );
      body.angularVelocity *= 0.82;
    }
  }

  void _resolveCollisions() {
    final absorbedBodies = <_PhysicsBody>{};
    for (var first = 0; first < _bodies.length; first++) {
      for (var second = first + 1; second < _bodies.length; second++) {
        final a = _bodies[first];
        final b = _bodies[second];
        if (absorbedBodies.contains(a) || absorbedBodies.contains(b)) continue;
        if (a.isDragging || b.isDragging) continue;

        final aRect = _bodyRect(a);
        final bRect = _bodyRect(b);
        if (!aRect.overlaps(bRect)) continue;

        final aIsResetLogo =
            a.element.id == 'app-logo' && a.instanceId == 'initial-0';
        final bIsResetLogo =
            b.element.id == 'app-logo' && b.instanceId == 'initial-0';
        final aMass = _mass(a);
        final bMass = _mass(b);
        final eater = aIsResetLogo
            ? a
            : bIsResetLogo
            ? b
            : aMass >= bMass
            ? a
            : b;
        final eaten = identical(eater, a) ? b : a;

        final eaterMass = identical(eater, a) ? aMass : bMass;
        final eatenMass = identical(eater, a) ? bMass : aMass;
        _absorb(eater, eaten, eaterMass, eatenMass);
        absorbedBodies.add(eaten);
      }
    }
    _bodies.removeWhere(absorbedBodies.contains);
  }

  double _mass(_PhysicsBody body) => body.size.width * body.size.height;

  void _absorb(
    _PhysicsBody eater,
    _PhysicsBody eaten,
    double eaterMass,
    double eatenMass,
  ) {
    final oldSize = eater.size;
    final baseArea = eater.element.size.width * eater.element.size.height;
    final scaleFromMass = math.sqrt((eaterMass + eatenMass) / baseArea);
    final widthScale = _boardSize.width / eater.element.size.width;
    final heightScale = _boardSize.height / eater.element.size.height;
    final maxScale = math.max(
      1.0,
      math.min(2.8, math.min(widthScale, heightScale)),
    );

    eater.scale = math.min(scaleFromMass, maxScale).toDouble();
    eater.eatenCount += eaten.eatenCount + 1;
    eater.position += Offset(
      (oldSize.width - eater.size.width) / 2,
      (oldSize.height - eater.size.height) / 2,
    );

    final totalMass = eaterMass + eatenMass;
    eater.velocity =
        (eater.velocity * eaterMass + eaten.velocity * eatenMass) / totalMass;
    eater.angularVelocity = (eater.angularVelocity + eaten.angularVelocity) / 2;
  }

  Rect _bodyRect(_PhysicsBody body) => Rect.fromLTWH(
    body.position.dx,
    body.position.dy,
    body.size.width,
    body.size.height,
  );

  List<_PhysicsBody> _createBodies(Size size) {
    return [
      for (var index = 0; index < widget.elements.length; index++)
        _PhysicsBody(
          element: widget.elements[index],
          instanceId: 'initial-$index',
          child: widget.elements[index].builder(
            _elementKey(widget.elements[index]),
          ),
          position: _initialPosition(widget.elements[index], index, size),
          velocity: Offset(index.isEven ? -48.0 : 40.0, -55.0 + index * 14),
          angle: (index - 1.5) * 0.055,
          angularVelocity: index.isEven ? 0.8 : -0.85,
        ),
    ];
  }

  Key _elementKey(PhysicsElement element) => ValueKey('physics-${element.id}');

  void _handleBoardPointerDown(PointerDownEvent event) {
    final isPrimaryMouseClick =
        event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) != 0;
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (!isPrimaryMouseClick && !isTouch) return;

    for (final body in _bodies.reversed) {
      if (_bodyRect(body).contains(event.localPosition)) {
        _startDragging(body, event);
        return;
      }
    }

    _spawnElement(event.localPosition);
  }

  void _handleBoardPointerMove(PointerMoveEvent event) {
    for (final body in _bodies) {
      if (body.pointerId == event.pointer) {
        _drag(body, event);
        return;
      }
    }
  }

  void _handleBoardPointerEnd(PointerEvent event) {
    for (final body in _bodies) {
      if (body.pointerId == event.pointer) {
        _release(body, event);
        return;
      }
    }
  }

  void _spawnElement(Offset center) {
    if (_bodies.length >= 30 || widget.elements.isEmpty) return;

    final element = widget.elements[_random.nextInt(widget.elements.length)];
    final instance = _nextSpawnId++;
    final key = ValueKey('physics-${element.id}-spawn-$instance');
    final maxX = math.max(0.0, _boardSize.width - element.size.width);
    final maxY = math.max(0.0, _boardSize.height - element.size.height);
    final position = Offset(
      (center.dx - element.size.width / 2).clamp(0.0, maxX).toDouble(),
      (center.dy - element.size.height / 2).clamp(0.0, maxY).toDouble(),
    );
    final body = _PhysicsBody(
      element: element,
      instanceId: 'spawn-$instance',
      child: element.builder(key),
      position: position,
      velocity: Offset(
        _random.nextDouble() * 260 - 130,
        _random.nextDouble() * -180 - 80,
      ),
      angle: _random.nextDouble() * 0.5 - 0.25,
      angularVelocity: _random.nextDouble() * 2 - 1,
    );
    setState(() => _bodies.add(body));
  }

  Offset _initialPosition(PhysicsElement element, int index, Size size) {
    final maxX = math.max(0.0, size.width - element.size.width);
    final maxY = math.max(0.0, size.height - element.size.height);
    final offset = index.isEven ? -32.0 : 32.0;
    final left = ((size.width - element.size.width) / 2 + offset)
        .clamp(0.0, maxX)
        .toDouble();
    final top = (72.0 + index * 128).clamp(0.0, maxY).toDouble();
    return Offset(left, top);
  }

  void _startDragging(_PhysicsBody body, PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }

    setState(() {
      body.isDragging = true;
      body.pointerId = event.pointer;
      body.velocity = Offset.zero;
      body.dragVelocity = Offset.zero;
      body.angularVelocity = 0;
    });
  }

  void _drag(_PhysicsBody body, PointerMoveEvent event) {
    if (body.pointerId != event.pointer) return;

    setState(() {
      final maxX = math.max(0.0, _boardSize.width - body.size.width).toDouble();
      final maxY = math
          .max(0.0, _boardSize.height - body.size.height)
          .toDouble();
      body.position = Offset(
        (body.position.dx + event.delta.dx).clamp(0.0, maxX).toDouble(),
        (body.position.dy + event.delta.dy).clamp(0.0, maxY).toDouble(),
      );
      body.dragVelocity = event.delta * 50;
    });
  }

  void _release(_PhysicsBody body, PointerEvent event) {
    if (body.pointerId != event.pointer) return;

    setState(() {
      body.isDragging = false;
      body.pointerId = null;
      body.velocity = Offset(
        body.dragVelocity.dx.clamp(-700.0, 700.0).toDouble(),
        body.dragVelocity.dy.clamp(-700.0, 700.0).toDouble(),
      );
      body.angularVelocity =
          body.dragVelocity.dx.clamp(-700.0, 700.0).toDouble() / 260;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _boardSize) {
          _boardSize = size;
          _bodies = _createBodies(size);
          _lastFrame = null;
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handleBoardPointerDown,
          onPointerMove: _handleBoardPointerMove,
          onPointerUp: _handleBoardPointerEnd,
          onPointerCancel: _handleBoardPointerEnd,
          child: Stack(
            key: const Key('physics-board'),
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.surfaceContainerLow,
                        colors.primaryContainer.withValues(alpha: 0.5),
                        colors.tertiaryContainer.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CHAOS MODE | Collide to eat & grow; click or tap empty space to summon',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (final body in _bodies)
                Positioned(
                  key: ValueKey('physics-body-${body.instanceId}'),
                  left: body.position.dx,
                  top: body.position.dy,
                  width: body.size.width,
                  height: body.size.height,
                  child: MouseRegion(
                    cursor: body.isDragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: Transform.rotate(
                      angle: body.angle,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: body.element.size.width,
                            height: body.element.size.height,
                            child: Transform.scale(
                              scale: body.scale,
                              child: body.child,
                            ),
                          ),
                          if (body.eatenCount > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.tertiary,
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.tertiary.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    'x${body.eatenCount + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: colors.onTertiary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhysicsBody {
  _PhysicsBody({
    required this.element,
    required this.instanceId,
    required this.child,
    required this.position,
    required this.velocity,
    required this.angle,
    required this.angularVelocity,
  });

  final PhysicsElement element;
  final String instanceId;
  final Widget child;
  Offset position;
  Offset velocity;
  double angle;
  double angularVelocity;
  double scale = 1;
  int eatenCount = 0;
  int? pointerId;
  Offset dragVelocity = Offset.zero;
  bool isDragging = false;

  Size get size =>
      Size(element.size.width * scale, element.size.height * scale);
}
