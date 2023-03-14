import 'package:code_builder/code_builder.dart'
    show
        Class,
        Expression,
        TypeReference,
        literalNull,
        literalMap,
        literalList,
        refer;
import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' show Input;
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart' show ReCase;
import '../utils.dart' as utils show findCommonType;
import '../constants.dart' as constants;
import '../class_builder.dart'
    show
        createVariantBaseClass,
        createVariantValuesClass,
        createVariantCodec,
        createVariantClass,
        createSimpleVariantEnum,
        createSimpleVariantCodec;
import './base.dart' show BasePath, Generator, GeneratedOutput, Field;

class Variant extends Generator {
  int index;
  String name;
  String orignalName;
  List<Field> fields;
  List<String> docs;
  late VariantGenerator generator;

  Variant({
    required this.index,
    required this.name,
    required this.orignalName,
    required this.fields,
    required this.docs,
  }) {
    for (int i = 0; i < fields.length; i++) {
      if (fields[i].originalName == null) {
        fields[i].sanitizedName = 'value$i';
      }
    }
  }

  @override
  TypeReference jsonType(BasePath from, [Set<Generator> visited = const {}]) {
    if (fields.isEmpty) {
      return constants.map(constants.string, constants.dynamic);
    }

    if (visited.contains(this)) {
      if (fields.length == 1 && fields.first.originalName == null) {
        return constants.map(constants.string, constants.dynamic);
      }
    }
    visited.add(this);

    final TypeReference newType;
    if (fields.length == 1 && fields.first.originalName == null) {
      newType = constants.map(
          constants.string, fields.first.codec.jsonType(from, visited));
    } else {
      // Check if all fields are of the same type, otherwise use dynamic
      final type = utils.findCommonType(
          fields.map((field) => field.codec.jsonType(from, visited)));

      if (fields.every((field) => field.originalName == null)) {
        newType = constants.map(constants.string, constants.list(ref: type));
      } else {
        newType = constants.map(
            constants.string, constants.map(constants.string, type));
      }
    }
    visited.remove(this);

    return newType;
  }

  Expression toJson(BasePath from) {
    if (fields.isEmpty) {
      return literalMap({orignalName: literalNull});
    }
    if (fields.length == 1 && fields.first.originalName == null) {
      return literalMap({
        orignalName: fields.first.codec
            .instanceToJson(from, refer(fields.first.sanitizedName))
      });
    }
    if (fields.every((field) => field.originalName == null)) {
      return literalMap({
        orignalName: literalList(fields.map((field) =>
            field.codec.instanceToJson(from, refer(field.sanitizedName))))
      });
    }
    return literalMap({
      orignalName: literalMap({
        for (final field in fields)
          ReCase(field.originalOrSanitizedName()).camelCase:
              field.codec.instanceToJson(from, refer(field.sanitizedName))
      })
    });
  }

  @override
  TypeReference codec(BasePath from) {
    throw UnimplementedError();
  }

  @override
  Expression instanceToJson(BasePath from, Expression obj) {
    throw UnimplementedError();
  }

  @override
  TypeReference primitive(BasePath from) {
    return TypeReference((b) => b
      ..symbol = name
      ..url = p.relative(generator.filePath, from: from));
  }

  @override
  Expression valueFrom(BasePath from, Input input, {bool constant = false}) {
    throw UnimplementedError();
  }
}

class VariantGenerator extends Generator {
  String filePath;
  String name;
  List<Variant> variants;
  List<String> docs;

  VariantGenerator(
      {required this.filePath,
      required this.name,
      required this.variants,
      required this.docs}) {
    for (final variant in variants) {
      variant.generator = this;
    }
  }

  @override
  TypeReference codec(BasePath from) {
    return TypeReference((b) => b
      ..symbol = name
      ..url = p.relative(filePath, from: from));
  }

  @override
  TypeReference primitive(BasePath from) {
    return TypeReference((b) => b
      ..symbol = name
      ..url = p.relative(filePath, from: from));
  }

  @override
  Expression valueFrom(BasePath from, Input input, {bool constant = false}) {
    final index = input.read();
    final variant = variants.firstWhere((variant) => variant.index == index);

    if (variants.isNotEmpty &&
        variants.every((variant) => variant.fields.isEmpty)) {
      return primitive(from).property(ReCase(variant.name).camelCase);
    }

    final variantType = variant.primitive(from);
    final values = <String, Expression>{
      for (final field in variant.fields)
        field.sanitizedName: field.codec.valueFrom(from, input)
    };
    if (values.values.every((value) => value.isConst)) {
      return variantType.constInstance([], values);
    }
    return variantType.newInstance([], values);
  }

  @override
  GeneratedOutput? generated() {
    // Simple Variants
    if (variants.isNotEmpty &&
        variants.every((variant) => variant.fields.isEmpty)) {
      final simpleEnum = createSimpleVariantEnum(this);
      final simpleCodec =
          createSimpleVariantCodec(filePath, '_\$${name}Codec', name, variants);
      return GeneratedOutput(
          classes: [simpleCodec], enums: [simpleEnum], typedefs: []);
    }

    // Complex Variants
    final complexJsonType = jsonType(p.dirname(filePath), {});
    final baseClass = createVariantBaseClass(this, complexJsonType);
    final valuesClass = createVariantValuesClass(this);
    final codecClass = createVariantCodec(this);

    final List<Class> classes = variants
        .fold(<Class>[baseClass, valuesClass, codecClass], (classes, variant) {
      classes.add(createVariantClass(
          filePath, name, '_\$${name}Codec', variant, complexJsonType));
      return classes;
    });
    return GeneratedOutput(classes: classes, enums: [], typedefs: []);
  }

  @override
  TypeReference jsonType(BasePath from, [Set<Generator> visited = const {}]) {
    // For Simple Variants json type is String
    if (variants.isNotEmpty &&
        variants.every((variant) => variant.fields.isEmpty)) {
      return constants.string.type as TypeReference;
    }

    if (visited.contains(this)) {
      return constants.map(constants.string, constants.dynamic);
    }

    visited.add(this);
    final type = Generator.cacheOrCreate(from, visited, () {
      // Check if all variants are of the same type, otherwise use Map<String, dynamic>
      final complexJsonType = utils.findCommonType(
          variants.map((variant) => variant.jsonType(from, visited)));
      if (complexJsonType.symbol != 'Map') {
        throw Exception(
            '$name: Invalid complex variant type: $complexJsonType');
      }
      return complexJsonType;
    });
    visited.remove(this);
    return type;
  }

  @override
  Expression instanceToJson(BasePath from, Expression obj) {
    return obj.property('toJson').call([]);
  }
}
