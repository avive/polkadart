import 'package:code_builder/code_builder.dart'
    show Class, Expression, TypeReference;
import 'package:polkadart_scale_codec/polkadart_scale_codec.dart' show Input;
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart' show ReCase;
import '../class_builder.dart'
    show
        createVariantBaseClass,
        createVariantValuesClass,
        createVariantCodec,
        createVariantClass,
        createSimpleVariantEnum,
        createSimpleVariantCodec;
import './base.dart' show BasePath, Generator, GeneratedOutput, Field;

class Variant {
  int index;
  String name;
  List<Field> fields;
  List<String> docs;

  Variant({
    required this.index,
    required this.name,
    required this.fields,
    required this.docs,
  });
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
      required this.docs});

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
  Expression valueFrom(BasePath from, Input input) {
    final index = input.read();
    final variant = variants.firstWhere((variant) => variant.index == index);

    if (variants.isNotEmpty &&
        variants.every((variant) => variant.fields.isEmpty)) {
      return primitive(from).property(ReCase(variant.name).camelCase);
    }

    return primitive(from)
        .property('values')
        .property(ReCase(variant.name).camelCase)
        .call([], {
      for (final field in variant.fields)
        field.name: field.codec.valueFrom(from, input)
    });
  }

  @override
  GeneratedOutput? generated() {
    if (variants.isNotEmpty &&
        variants.every((variant) => variant.fields.isEmpty)) {
      final simpleEnum = createSimpleVariantEnum(this);
      final simpleCodec =
          createSimpleVariantCodec(filePath, '_\$${name}Codec', name, variants);
      return GeneratedOutput(
          classes: [simpleCodec], enums: [simpleEnum], typedefs: []);
    }

    final baseClass = createVariantBaseClass(this);
    final valuesClass = createVariantValuesClass(this);
    final codecClass = createVariantCodec(this);

    final List<Class> classes = variants
        .fold(<Class>[baseClass, valuesClass, codecClass], (classes, variant) {
      classes
          .add(createVariantClass(filePath, name, '_\$${name}Codec', variant));
      return classes;
    });
    return GeneratedOutput(classes: classes, enums: [], typedefs: []);
  }

  @override
  Expression instanceToJson(BasePath from, Expression obj) {
    return obj.property('toJson').call([]);
  }
}
