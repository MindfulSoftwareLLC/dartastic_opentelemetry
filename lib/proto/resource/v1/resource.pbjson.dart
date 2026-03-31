// This is a generated file - do not edit.
//
// Generated from opentelemetry/proto/resource/v1/resource.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use resourceDescriptor instead')
const Resource$json = {
  '1': 'Resource',
  '2': [
    {
      '1': 'attributes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.opentelemetry.proto.common.v1.KeyValue',
      '10': 'attributes'
    },
    {
      '1': 'dropped_attributes_count',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'droppedAttributesCount'
    },
  ],
};

/// Descriptor for `Resource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resourceDescriptor = $convert.base64Decode(
    'CghSZXNvdXJjZRJHCgphdHRyaWJ1dGVzGAEgAygLMicub3BlbnRlbGVtZXRyeS5wcm90by5jb2'
    '1tb24udjEuS2V5VmFsdWVSCmF0dHJpYnV0ZXMSOAoYZHJvcHBlZF9hdHRyaWJ1dGVzX2NvdW50'
    'GAIgASgNUhZkcm9wcGVkQXR0cmlidXRlc0NvdW50');
