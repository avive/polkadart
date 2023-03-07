part of primitives;

class U64Codec with Codec<BigInt> {
  const U64Codec._();

  static const U64Codec codec = U64Codec._();

  @override
  void encodeTo(BigInt value, Output output) {
    U32Codec.codec
      ..encodeTo(value.toUnsigned(32).toInt(), output)
      ..encodeTo((value >> 32).toUnsigned(32).toInt(), output);
  }

  @override
  BigInt decode(Input input) {
    final low = U32Codec.codec.decode(input);
    final high = U32Codec.codec.decode(input);
    return BigInt.from(low) | (BigInt.from(high) << 32);
  }

  @override
  int sizeHint(BigInt value) {
    return 8;
  }
}

class U64SequenceCodec with Codec<Uint64List> {
  const U64SequenceCodec._();

  static const U64SequenceCodec codec = U64SequenceCodec._();

  @override
  Uint64List decode(Input input) {
    final length = CompactCodec.codec.decode(input).toInt();
    final list = Uint64List(length);
    for (var i = 0; i < length; i++) {
      list[i] = U64Codec.codec.decode(input).toInt();
    }
    return list;
  }

  @override
  void encodeTo(Uint64List value, Output output) {
    CompactCodec.codec.encodeTo(value.length, output);
    for (var i = 0; i < value.length; i++) {
      U64Codec.codec.encodeTo(BigInt.from(value[i]), output);
    }
  }

  @override
  int sizeHint(Uint64List value) {
    return CompactCodec.codec.sizeHint(value.length) + value.lengthInBytes;
  }
}

class U64ArrayCodec with Codec<Uint64List> {
  final int length;
  const U64ArrayCodec(this.length);

  @override
  Uint64List decode(Input input) {
    final list = Uint64List(length);
    for (var i = 0; i < length; i++) {
      list[i] = U64Codec.codec.decode(input).toInt();
    }
    return list;
  }

  @override
  void encodeTo(Uint64List value, Output output) {
    if (value.length != length) {
      throw Exception(
          'U64ArrayCodec: invalid length, expect $length found ${value.length}');
    }
    for (var i = 0; i < length; i++) {
      U64Codec.codec.encodeTo(BigInt.from(value[i]), output);
    }
  }

  @override
  int sizeHint(Uint64List list) {
    return length * 8;
  }
}
