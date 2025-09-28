// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.

//
//  Generated code. Do not modify.
//  source: opentelemetry/proto/metrics/v1/metrics.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references, public_member_api_docs
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../../common/v1/common.pb.dart' as $3;
import '../../resource/v1/resource.pb.dart' as $4;
import 'metrics.pbenum.dart';

export 'metrics.pbenum.dart';

///  MetricsData represents the metrics data that can be stored in a persistent
///  storage, OR can be embedded by other protocols that transfer OTLP metrics
///  data but do not implement the OTLP protocol.
///
///  The main difference between this message and collector protocol is that
///  in this message there will not be any "control" or "metadata" specific to
///  OTLP protocol.
///
///  When new fields are added into this message, the OTLP request MUST be updated
///  as well.
class MetricsData extends $pb.GeneratedMessage {
  factory MetricsData({
    $core.Iterable<ResourceMetrics>? resourceMetrics,
  }) {
    final $result = create();
    if (resourceMetrics != null) {
      $result.resourceMetrics.addAll(resourceMetrics);
    }
    return $result;
  }
  MetricsData._() : super();
  factory MetricsData.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory MetricsData.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MetricsData',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<ResourceMetrics>(
        1, _omitFieldNames ? '' : 'resourceMetrics', $pb.PbFieldType.PM,
        subBuilder: ResourceMetrics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MetricsData clone() => MetricsData()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MetricsData copyWith(void Function(MetricsData) updates) =>
      super.copyWith((message) => updates(message as MetricsData))
          as MetricsData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MetricsData create() => MetricsData._();
  MetricsData createEmptyInstance() => create();
  static $pb.PbList<MetricsData> createRepeated() => $pb.PbList<MetricsData>();
  @$core.pragma('dart2js:noInline')
  static MetricsData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MetricsData>(create);
  static MetricsData? _defaultInstance;

  /// An array of ResourceMetrics.
  /// For data coming from a single resource this array will typically contain
  /// one element. Intermediary nodes that receive data from multiple origins
  /// typically batch the data before forwarding further and in that case this
  /// array will contain multiple elements.
  @$pb.TagNumber(1)
  $core.List<ResourceMetrics> get resourceMetrics => $_getList(0);
}

/// A collection of ScopeMetrics from a Resource.
class ResourceMetrics extends $pb.GeneratedMessage {
  factory ResourceMetrics({
    $4.Resource? resource,
    $core.Iterable<ScopeMetrics>? scopeMetrics,
    $core.String? schemaUrl,
  }) {
    final $result = create();
    if (resource != null) {
      $result.resource = resource;
    }
    if (scopeMetrics != null) {
      $result.scopeMetrics.addAll(scopeMetrics);
    }
    if (schemaUrl != null) {
      $result.schemaUrl = schemaUrl;
    }
    return $result;
  }
  ResourceMetrics._() : super();
  factory ResourceMetrics.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ResourceMetrics.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResourceMetrics',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..aOM<$4.Resource>(1, _omitFieldNames ? '' : 'resource',
        subBuilder: $4.Resource.create)
    ..pc<ScopeMetrics>(
        2, _omitFieldNames ? '' : 'scopeMetrics', $pb.PbFieldType.PM,
        subBuilder: ScopeMetrics.create)
    ..aOS(3, _omitFieldNames ? '' : 'schemaUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ResourceMetrics clone() => ResourceMetrics()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ResourceMetrics copyWith(void Function(ResourceMetrics) updates) =>
      super.copyWith((message) => updates(message as ResourceMetrics))
          as ResourceMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResourceMetrics create() => ResourceMetrics._();
  ResourceMetrics createEmptyInstance() => create();
  static $pb.PbList<ResourceMetrics> createRepeated() =>
      $pb.PbList<ResourceMetrics>();
  @$core.pragma('dart2js:noInline')
  static ResourceMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResourceMetrics>(create);
  static ResourceMetrics? _defaultInstance;

  /// The resource for the metrics in this message.
  /// If this field is not set then no resource info is known.
  @$pb.TagNumber(1)
  $4.Resource get resource => $_getN(0);
  @$pb.TagNumber(1)
  set resource($4.Resource v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasResource() => $_has(0);
  @$pb.TagNumber(1)
  void clearResource() => clearField(1);
  @$pb.TagNumber(1)
  $4.Resource ensureResource() => $_ensure(0);

  /// A list of metrics that originate from a resource.
  @$pb.TagNumber(2)
  $core.List<ScopeMetrics> get scopeMetrics => $_getList(1);

  /// The Schema URL, if known. This is the identifier of the Schema that the resource data
  /// is recorded in. To learn more about Schema URL see
  /// https://opentelemetry.io/docs/specs/otel/schemas/#schema-url
  /// This schema_url applies to the data in the "resource" field. It does not apply
  /// to the data in the "scope_metrics" field which have their own schema_url field.
  @$pb.TagNumber(3)
  $core.String get schemaUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaUrl($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSchemaUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaUrl() => clearField(3);
}

/// A collection of Metrics produced by an Scope.
class ScopeMetrics extends $pb.GeneratedMessage {
  factory ScopeMetrics({
    $3.InstrumentationScope? scope,
    $core.Iterable<Metric>? metrics,
    $core.String? schemaUrl,
  }) {
    final $result = create();
    if (scope != null) {
      $result.scope = scope;
    }
    if (metrics != null) {
      $result.metrics.addAll(metrics);
    }
    if (schemaUrl != null) {
      $result.schemaUrl = schemaUrl;
    }
    return $result;
  }
  ScopeMetrics._() : super();
  factory ScopeMetrics.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ScopeMetrics.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ScopeMetrics',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..aOM<$3.InstrumentationScope>(1, _omitFieldNames ? '' : 'scope',
        subBuilder: $3.InstrumentationScope.create)
    ..pc<Metric>(2, _omitFieldNames ? '' : 'metrics', $pb.PbFieldType.PM,
        subBuilder: Metric.create)
    ..aOS(3, _omitFieldNames ? '' : 'schemaUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ScopeMetrics clone() => ScopeMetrics()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ScopeMetrics copyWith(void Function(ScopeMetrics) updates) =>
      super.copyWith((message) => updates(message as ScopeMetrics))
          as ScopeMetrics;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ScopeMetrics create() => ScopeMetrics._();
  ScopeMetrics createEmptyInstance() => create();
  static $pb.PbList<ScopeMetrics> createRepeated() =>
      $pb.PbList<ScopeMetrics>();
  @$core.pragma('dart2js:noInline')
  static ScopeMetrics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ScopeMetrics>(create);
  static ScopeMetrics? _defaultInstance;

  /// The instrumentation scope information for the metrics in this message.
  /// Semantically when InstrumentationScope isn't set, it is equivalent with
  /// an empty instrumentation scope name (unknown).
  @$pb.TagNumber(1)
  $3.InstrumentationScope get scope => $_getN(0);
  @$pb.TagNumber(1)
  set scope($3.InstrumentationScope v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasScope() => $_has(0);
  @$pb.TagNumber(1)
  void clearScope() => clearField(1);
  @$pb.TagNumber(1)
  $3.InstrumentationScope ensureScope() => $_ensure(0);

  /// A list of metrics that originate from an instrumentation library.
  @$pb.TagNumber(2)
  $core.List<Metric> get metrics => $_getList(1);

  /// The Schema URL, if known. This is the identifier of the Schema that the metric data
  /// is recorded in. To learn more about Schema URL see
  /// https://opentelemetry.io/docs/specs/otel/schemas/#schema-url
  /// This schema_url applies to all metrics in the "metrics" field.
  @$pb.TagNumber(3)
  $core.String get schemaUrl => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaUrl($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSchemaUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaUrl() => clearField(3);
}

enum Metric_Data {
  gauge,
  sum,
  histogram,
  exponentialHistogram,
  summary,
  notSet
}

///  Defines a Metric which has one or more timeseries.  The following is a
///  brief summary of the Metric data model.  For more details, see:
///
///    https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/data-model.md
///
///
///  The data model and relation between entities is shown in the
///  diagram below. Here, "DataPoint" is the term used to refer to any
///  one of the specific data point value types, and "points" is the term used
///  to refer to any one of the lists of points contained in the Metric.
///
///  - Metric is composed of a metadata and data.
///  - Metadata part contains a name, description, unit.
///  - Data is one of the possible types (Sum, Gauge, Histogram, Summary).
///  - DataPoint contains timestamps, attributes, and one of the possible value type
///    fields.
///
///      Metric
///   +------------+
///   |name        |
///   |description |
///   |unit        |     +------------------------------------+
///   |data        |---> |Gauge, Sum, Histogram, Summary, ... |
///   +------------+     +------------------------------------+
///
///     Data [One of Gauge, Sum, Histogram, Summary, ...]
///   +-----------+
///   |...        |  // Metadata about the Data.
///   |points     |--+
///   +-----------+  |
///                  |      +---------------------------+
///                  |      |DataPoint 1                |
///                  v      |+------+------+   +------+ |
///               +-----+   ||label |label |...|label | |
///               |  1  |-->||value1|value2|...|valueN| |
///               +-----+   |+------+------+   +------+ |
///               |  .  |   |+-----+                    |
///               |  .  |   ||value|                    |
///               |  .  |   |+-----+                    |
///               |  .  |   +---------------------------+
///               |  .  |                   .
///               |  .  |                   .
///               |  .  |                   .
///               |  .  |   +---------------------------+
///               |  .  |   |DataPoint M                |
///               +-----+   |+------+------+   +------+ |
///               |  M  |-->||label |label |...|label | |
///               +-----+   ||value1|value2|...|valueN| |
///                         |+------+------+   +------+ |
///                         |+-----+                    |
///                         ||value|                    |
///                         |+-----+                    |
///                         +---------------------------+
///
///  Each distinct type of DataPoint represents the output of a specific
///  aggregation function, the result of applying the DataPoint's
///  associated function of to one or more measurements.
///
///  All DataPoint types have three common fields:
///  - Attributes includes key-value pairs associated with the data point
///  - TimeUnixNano is required, set to the end time of the aggregation
///  - StartTimeUnixNano is optional, but strongly encouraged for DataPoints
///    having an AggregationTemporality field, as discussed below.
///
///  Both TimeUnixNano and StartTimeUnixNano values are expressed as
///  UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January 1970.
///
///  # TimeUnixNano
///
///  This field is required, having consistent interpretation across
///  DataPoint types.  TimeUnixNano is the moment corresponding to when
///  the data point's aggregate value was captured.
///
///  Data points with the 0 value for TimeUnixNano SHOULD be rejected
///  by consumers.
///
///  # StartTimeUnixNano
///
///  StartTimeUnixNano in general allows detecting when a sequence of
///  observations is unbroken.  This field indicates to consumers the
///  start time for points with cumulative and delta
///  AggregationTemporality, and it should be included whenever possible
///  to support correct rate calculation.  Although it may be omitted
///  when the start time is truly unknown, setting StartTimeUnixNano is
///  strongly encouraged.
class Metric extends $pb.GeneratedMessage {
  factory Metric({
    $core.String? name,
    $core.String? description,
    $core.String? unit,
    Gauge? gauge,
    Sum? sum,
    Histogram? histogram,
    ExponentialHistogram? exponentialHistogram,
    Summary? summary,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (description != null) {
      $result.description = description;
    }
    if (unit != null) {
      $result.unit = unit;
    }
    if (gauge != null) {
      $result.gauge = gauge;
    }
    if (sum != null) {
      $result.sum = sum;
    }
    if (histogram != null) {
      $result.histogram = histogram;
    }
    if (exponentialHistogram != null) {
      $result.exponentialHistogram = exponentialHistogram;
    }
    if (summary != null) {
      $result.summary = summary;
    }
    return $result;
  }
  Metric._() : super();
  factory Metric.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Metric.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, Metric_Data> _Metric_DataByTag = {
    5: Metric_Data.gauge,
    7: Metric_Data.sum,
    9: Metric_Data.histogram,
    10: Metric_Data.exponentialHistogram,
    11: Metric_Data.summary,
    0: Metric_Data.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Metric',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..oo(0, [5, 7, 9, 10, 11])
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'unit')
    ..aOM<Gauge>(5, _omitFieldNames ? '' : 'gauge', subBuilder: Gauge.create)
    ..aOM<Sum>(7, _omitFieldNames ? '' : 'sum', subBuilder: Sum.create)
    ..aOM<Histogram>(9, _omitFieldNames ? '' : 'histogram',
        subBuilder: Histogram.create)
    ..aOM<ExponentialHistogram>(
        10, _omitFieldNames ? '' : 'exponentialHistogram',
        subBuilder: ExponentialHistogram.create)
    ..aOM<Summary>(11, _omitFieldNames ? '' : 'summary',
        subBuilder: Summary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Metric clone() => Metric()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Metric copyWith(void Function(Metric) updates) =>
      super.copyWith((message) => updates(message as Metric)) as Metric;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Metric create() => Metric._();
  Metric createEmptyInstance() => create();
  static $pb.PbList<Metric> createRepeated() => $pb.PbList<Metric>();
  @$core.pragma('dart2js:noInline')
  static Metric getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Metric>(create);
  static Metric? _defaultInstance;

  Metric_Data whichData() => _Metric_DataByTag[$_whichOneof(0)]!;
  void clearData() => clearField($_whichOneof(0));

  /// name of the metric.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  /// description of the metric, which can be used in documentation.
  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => clearField(2);

  /// unit in which the metric value is reported. Follows the format
  /// described by http://unitsofmeasure.org/ucum.html.
  @$pb.TagNumber(3)
  $core.String get unit => $_getSZ(2);
  @$pb.TagNumber(3)
  set unit($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasUnit() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnit() => clearField(3);

  @$pb.TagNumber(5)
  Gauge get gauge => $_getN(3);
  @$pb.TagNumber(5)
  set gauge(Gauge v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasGauge() => $_has(3);
  @$pb.TagNumber(5)
  void clearGauge() => clearField(5);
  @$pb.TagNumber(5)
  Gauge ensureGauge() => $_ensure(3);

  @$pb.TagNumber(7)
  Sum get sum => $_getN(4);
  @$pb.TagNumber(7)
  set sum(Sum v) {
    setField(7, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasSum() => $_has(4);
  @$pb.TagNumber(7)
  void clearSum() => clearField(7);
  @$pb.TagNumber(7)
  Sum ensureSum() => $_ensure(4);

  @$pb.TagNumber(9)
  Histogram get histogram => $_getN(5);
  @$pb.TagNumber(9)
  set histogram(Histogram v) {
    setField(9, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasHistogram() => $_has(5);
  @$pb.TagNumber(9)
  void clearHistogram() => clearField(9);
  @$pb.TagNumber(9)
  Histogram ensureHistogram() => $_ensure(5);

  @$pb.TagNumber(10)
  ExponentialHistogram get exponentialHistogram => $_getN(6);
  @$pb.TagNumber(10)
  set exponentialHistogram(ExponentialHistogram v) {
    setField(10, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasExponentialHistogram() => $_has(6);
  @$pb.TagNumber(10)
  void clearExponentialHistogram() => clearField(10);
  @$pb.TagNumber(10)
  ExponentialHistogram ensureExponentialHistogram() => $_ensure(6);

  @$pb.TagNumber(11)
  Summary get summary => $_getN(7);
  @$pb.TagNumber(11)
  set summary(Summary v) {
    setField(11, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasSummary() => $_has(7);
  @$pb.TagNumber(11)
  void clearSummary() => clearField(11);
  @$pb.TagNumber(11)
  Summary ensureSummary() => $_ensure(7);
}

///  Gauge represents the type of a scalar metric that always exports the
///  "current value" for every data point. It should be used for an "unknown"
///  aggregation.
///
///  A Gauge does not support different aggregation temporalities. Given the
///  aggregation is unknown, points cannot be combined using the same
///  aggregation, regardless of aggregation temporalities. Therefore,
///  AggregationTemporality is not included. Consequently, this also means
///  "StartTimeUnixNano" is ignored for all data points.
class Gauge extends $pb.GeneratedMessage {
  factory Gauge({
    $core.Iterable<NumberDataPoint>? dataPoints,
  }) {
    final $result = create();
    if (dataPoints != null) {
      $result.dataPoints.addAll(dataPoints);
    }
    return $result;
  }
  Gauge._() : super();
  factory Gauge.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Gauge.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Gauge',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<NumberDataPoint>(
        1, _omitFieldNames ? '' : 'dataPoints', $pb.PbFieldType.PM,
        subBuilder: NumberDataPoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Gauge clone() => Gauge()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Gauge copyWith(void Function(Gauge) updates) =>
      super.copyWith((message) => updates(message as Gauge)) as Gauge;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Gauge create() => Gauge._();
  Gauge createEmptyInstance() => create();
  static $pb.PbList<Gauge> createRepeated() => $pb.PbList<Gauge>();
  @$core.pragma('dart2js:noInline')
  static Gauge getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Gauge>(create);
  static Gauge? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<NumberDataPoint> get dataPoints => $_getList(0);
}

/// Sum represents the type of a scalar metric that is calculated as a sum of all
/// reported measurements over a time interval.
class Sum extends $pb.GeneratedMessage {
  factory Sum({
    $core.Iterable<NumberDataPoint>? dataPoints,
    AggregationTemporality? aggregationTemporality,
    $core.bool? isMonotonic,
  }) {
    final $result = create();
    if (dataPoints != null) {
      $result.dataPoints.addAll(dataPoints);
    }
    if (aggregationTemporality != null) {
      $result.aggregationTemporality = aggregationTemporality;
    }
    if (isMonotonic != null) {
      $result.isMonotonic = isMonotonic;
    }
    return $result;
  }
  Sum._() : super();
  factory Sum.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Sum.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Sum',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<NumberDataPoint>(
        1, _omitFieldNames ? '' : 'dataPoints', $pb.PbFieldType.PM,
        subBuilder: NumberDataPoint.create)
    ..e<AggregationTemporality>(
        2, _omitFieldNames ? '' : 'aggregationTemporality', $pb.PbFieldType.OE,
        defaultOrMaker:
            AggregationTemporality.AGGREGATION_TEMPORALITY_UNSPECIFIED,
        valueOf: AggregationTemporality.valueOf,
        enumValues: AggregationTemporality.values)
    ..aOB(3, _omitFieldNames ? '' : 'isMonotonic')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Sum clone() => Sum()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Sum copyWith(void Function(Sum) updates) =>
      super.copyWith((message) => updates(message as Sum)) as Sum;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Sum create() => Sum._();
  Sum createEmptyInstance() => create();
  static $pb.PbList<Sum> createRepeated() => $pb.PbList<Sum>();
  @$core.pragma('dart2js:noInline')
  static Sum getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Sum>(create);
  static Sum? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<NumberDataPoint> get dataPoints => $_getList(0);

  /// aggregation_temporality describes if the aggregator reports delta changes
  /// since last report time, or cumulative changes since a fixed start time.
  @$pb.TagNumber(2)
  AggregationTemporality get aggregationTemporality => $_getN(1);
  @$pb.TagNumber(2)
  set aggregationTemporality(AggregationTemporality v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasAggregationTemporality() => $_has(1);
  @$pb.TagNumber(2)
  void clearAggregationTemporality() => clearField(2);

  /// If "true" means that the sum is monotonic.
  @$pb.TagNumber(3)
  $core.bool get isMonotonic => $_getBF(2);
  @$pb.TagNumber(3)
  set isMonotonic($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasIsMonotonic() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsMonotonic() => clearField(3);
}

/// Histogram represents the type of a metric that is calculated by aggregating
/// as a Histogram of all reported measurements over a time interval.
class Histogram extends $pb.GeneratedMessage {
  factory Histogram({
    $core.Iterable<HistogramDataPoint>? dataPoints,
    AggregationTemporality? aggregationTemporality,
  }) {
    final $result = create();
    if (dataPoints != null) {
      $result.dataPoints.addAll(dataPoints);
    }
    if (aggregationTemporality != null) {
      $result.aggregationTemporality = aggregationTemporality;
    }
    return $result;
  }
  Histogram._() : super();
  factory Histogram.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Histogram.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Histogram',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<HistogramDataPoint>(
        1, _omitFieldNames ? '' : 'dataPoints', $pb.PbFieldType.PM,
        subBuilder: HistogramDataPoint.create)
    ..e<AggregationTemporality>(
        2, _omitFieldNames ? '' : 'aggregationTemporality', $pb.PbFieldType.OE,
        defaultOrMaker:
            AggregationTemporality.AGGREGATION_TEMPORALITY_UNSPECIFIED,
        valueOf: AggregationTemporality.valueOf,
        enumValues: AggregationTemporality.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Histogram clone() => Histogram()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Histogram copyWith(void Function(Histogram) updates) =>
      super.copyWith((message) => updates(message as Histogram)) as Histogram;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Histogram create() => Histogram._();
  Histogram createEmptyInstance() => create();
  static $pb.PbList<Histogram> createRepeated() => $pb.PbList<Histogram>();
  @$core.pragma('dart2js:noInline')
  static Histogram getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Histogram>(create);
  static Histogram? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<HistogramDataPoint> get dataPoints => $_getList(0);

  /// aggregation_temporality describes if the aggregator reports delta changes
  /// since last report time, or cumulative changes since a fixed start time.
  @$pb.TagNumber(2)
  AggregationTemporality get aggregationTemporality => $_getN(1);
  @$pb.TagNumber(2)
  set aggregationTemporality(AggregationTemporality v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasAggregationTemporality() => $_has(1);
  @$pb.TagNumber(2)
  void clearAggregationTemporality() => clearField(2);
}

/// ExponentialHistogram represents the type of a metric that is calculated by aggregating
/// as a ExponentialHistogram of all reported double measurements over a time interval.
class ExponentialHistogram extends $pb.GeneratedMessage {
  factory ExponentialHistogram({
    $core.Iterable<ExponentialHistogramDataPoint>? dataPoints,
    AggregationTemporality? aggregationTemporality,
  }) {
    final $result = create();
    if (dataPoints != null) {
      $result.dataPoints.addAll(dataPoints);
    }
    if (aggregationTemporality != null) {
      $result.aggregationTemporality = aggregationTemporality;
    }
    return $result;
  }
  ExponentialHistogram._() : super();
  factory ExponentialHistogram.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ExponentialHistogram.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExponentialHistogram',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<ExponentialHistogramDataPoint>(
        1, _omitFieldNames ? '' : 'dataPoints', $pb.PbFieldType.PM,
        subBuilder: ExponentialHistogramDataPoint.create)
    ..e<AggregationTemporality>(
        2, _omitFieldNames ? '' : 'aggregationTemporality', $pb.PbFieldType.OE,
        defaultOrMaker:
            AggregationTemporality.AGGREGATION_TEMPORALITY_UNSPECIFIED,
        valueOf: AggregationTemporality.valueOf,
        enumValues: AggregationTemporality.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ExponentialHistogram clone() =>
      ExponentialHistogram()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ExponentialHistogram copyWith(void Function(ExponentialHistogram) updates) =>
      super.copyWith((message) => updates(message as ExponentialHistogram))
          as ExponentialHistogram;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExponentialHistogram create() => ExponentialHistogram._();
  ExponentialHistogram createEmptyInstance() => create();
  static $pb.PbList<ExponentialHistogram> createRepeated() =>
      $pb.PbList<ExponentialHistogram>();
  @$core.pragma('dart2js:noInline')
  static ExponentialHistogram getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExponentialHistogram>(create);
  static ExponentialHistogram? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<ExponentialHistogramDataPoint> get dataPoints => $_getList(0);

  /// aggregation_temporality describes if the aggregator reports delta changes
  /// since last report time, or cumulative changes since a fixed start time.
  @$pb.TagNumber(2)
  AggregationTemporality get aggregationTemporality => $_getN(1);
  @$pb.TagNumber(2)
  set aggregationTemporality(AggregationTemporality v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasAggregationTemporality() => $_has(1);
  @$pb.TagNumber(2)
  void clearAggregationTemporality() => clearField(2);
}

/// Summary metric data are used to convey quantile summaries,
/// a Prometheus (see: https://prometheus.io/docs/concepts/metric_types/#summary)
/// and OpenMetrics (see: https://github.com/OpenObservability/OpenMetrics/blob/4dbf6075567ab43296eed941037c12951faafb92/protos/prometheus.proto#L45)
/// data type. These data points cannot always be merged in a meaningful way.
/// While they can be useful in some applications, histogram data points are
/// recommended for new applications.
class Summary extends $pb.GeneratedMessage {
  factory Summary({
    $core.Iterable<SummaryDataPoint>? dataPoints,
  }) {
    final $result = create();
    if (dataPoints != null) {
      $result.dataPoints.addAll(dataPoints);
    }
    return $result;
  }
  Summary._() : super();
  factory Summary.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Summary.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Summary',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<SummaryDataPoint>(
        1, _omitFieldNames ? '' : 'dataPoints', $pb.PbFieldType.PM,
        subBuilder: SummaryDataPoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Summary clone() => Summary()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Summary copyWith(void Function(Summary) updates) =>
      super.copyWith((message) => updates(message as Summary)) as Summary;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Summary create() => Summary._();
  Summary createEmptyInstance() => create();
  static $pb.PbList<Summary> createRepeated() => $pb.PbList<Summary>();
  @$core.pragma('dart2js:noInline')
  static Summary getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Summary>(create);
  static Summary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SummaryDataPoint> get dataPoints => $_getList(0);
}

enum NumberDataPoint_Value { asDouble, asInt, notSet }

/// NumberDataPoint is a single data point in a timeseries that describes the
/// time-varying scalar value of a metric.
class NumberDataPoint extends $pb.GeneratedMessage {
  factory NumberDataPoint({
    $fixnum.Int64? startTimeUnixNano,
    $fixnum.Int64? timeUnixNano,
    $core.double? asDouble,
    $core.Iterable<Exemplar>? exemplars,
    $fixnum.Int64? asInt,
    $core.Iterable<$3.KeyValue>? attributes,
    $core.int? flags,
  }) {
    final $result = create();
    if (startTimeUnixNano != null) {
      $result.startTimeUnixNano = startTimeUnixNano;
    }
    if (timeUnixNano != null) {
      $result.timeUnixNano = timeUnixNano;
    }
    if (asDouble != null) {
      $result.asDouble = asDouble;
    }
    if (exemplars != null) {
      $result.exemplars.addAll(exemplars);
    }
    if (asInt != null) {
      $result.asInt = asInt;
    }
    if (attributes != null) {
      $result.attributes.addAll(attributes);
    }
    if (flags != null) {
      $result.flags = flags;
    }
    return $result;
  }
  NumberDataPoint._() : super();
  factory NumberDataPoint.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory NumberDataPoint.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, NumberDataPoint_Value>
      _NumberDataPoint_ValueByTag = {
    4: NumberDataPoint_Value.asDouble,
    6: NumberDataPoint_Value.asInt,
    0: NumberDataPoint_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NumberDataPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..oo(0, [4, 6])
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'startTimeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'asDouble', $pb.PbFieldType.OD)
    ..pc<Exemplar>(5, _omitFieldNames ? '' : 'exemplars', $pb.PbFieldType.PM,
        subBuilder: Exemplar.create)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'asInt', $pb.PbFieldType.OSF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pc<$3.KeyValue>(
        7, _omitFieldNames ? '' : 'attributes', $pb.PbFieldType.PM,
        subBuilder: $3.KeyValue.create)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'flags', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  NumberDataPoint clone() => NumberDataPoint()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  NumberDataPoint copyWith(void Function(NumberDataPoint) updates) =>
      super.copyWith((message) => updates(message as NumberDataPoint))
          as NumberDataPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NumberDataPoint create() => NumberDataPoint._();
  NumberDataPoint createEmptyInstance() => create();
  static $pb.PbList<NumberDataPoint> createRepeated() =>
      $pb.PbList<NumberDataPoint>();
  @$core.pragma('dart2js:noInline')
  static NumberDataPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NumberDataPoint>(create);
  static NumberDataPoint? _defaultInstance;

  NumberDataPoint_Value whichValue() =>
      _NumberDataPoint_ValueByTag[$_whichOneof(0)]!;
  void clearValue() => clearField($_whichOneof(0));

  ///  StartTimeUnixNano is optional but strongly encouraged, see the
  ///  the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(2)
  $fixnum.Int64 get startTimeUnixNano => $_getI64(0);
  @$pb.TagNumber(2)
  set startTimeUnixNano($fixnum.Int64 v) {
    $_setInt64(0, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStartTimeUnixNano() => $_has(0);
  @$pb.TagNumber(2)
  void clearStartTimeUnixNano() => clearField(2);

  ///  TimeUnixNano is required, see the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(3)
  $fixnum.Int64 get timeUnixNano => $_getI64(1);
  @$pb.TagNumber(3)
  set timeUnixNano($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimeUnixNano() => $_has(1);
  @$pb.TagNumber(3)
  void clearTimeUnixNano() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get asDouble => $_getN(2);
  @$pb.TagNumber(4)
  set asDouble($core.double v) {
    $_setDouble(2, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasAsDouble() => $_has(2);
  @$pb.TagNumber(4)
  void clearAsDouble() => clearField(4);

  /// (Optional) List of exemplars collected from
  /// measurements that were used to form the data point
  @$pb.TagNumber(5)
  $core.List<Exemplar> get exemplars => $_getList(3);

  @$pb.TagNumber(6)
  $fixnum.Int64 get asInt => $_getI64(4);
  @$pb.TagNumber(6)
  set asInt($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasAsInt() => $_has(4);
  @$pb.TagNumber(6)
  void clearAsInt() => clearField(6);

  /// The set of key/value pairs that uniquely identify the timeseries from
  /// where this point belongs. The list may be empty (may contain 0 elements).
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  @$pb.TagNumber(7)
  $core.List<$3.KeyValue> get attributes => $_getList(5);

  /// Flags that apply to this specific data point.  See DataPointFlags
  /// for the available flags and their meaning.
  @$pb.TagNumber(8)
  $core.int get flags => $_getIZ(6);
  @$pb.TagNumber(8)
  set flags($core.int v) {
    $_setUnsignedInt32(6, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasFlags() => $_has(6);
  @$pb.TagNumber(8)
  void clearFlags() => clearField(8);
}

///  HistogramDataPoint is a single data point in a timeseries that describes the
///  time-varying values of a Histogram. A Histogram contains summary statistics
///  for a population of values, it may optionally contain the distribution of
///  those values across a set of buckets.
///
///  If the histogram contains the distribution of values, then both
///  "explicit_bounds" and "bucket counts" fields must be defined.
///  If the histogram does not contain the distribution of values, then both
///  "explicit_bounds" and "bucket_counts" must be omitted and only "count" and
///  "sum" are known.
class HistogramDataPoint extends $pb.GeneratedMessage {
  factory HistogramDataPoint({
    $fixnum.Int64? startTimeUnixNano,
    $fixnum.Int64? timeUnixNano,
    $fixnum.Int64? count,
    $core.double? sum,
    $core.Iterable<$fixnum.Int64>? bucketCounts,
    $core.Iterable<$core.double>? explicitBounds,
    $core.Iterable<Exemplar>? exemplars,
    $core.Iterable<$3.KeyValue>? attributes,
    $core.int? flags,
    $core.double? min,
    $core.double? max,
  }) {
    final $result = create();
    if (startTimeUnixNano != null) {
      $result.startTimeUnixNano = startTimeUnixNano;
    }
    if (timeUnixNano != null) {
      $result.timeUnixNano = timeUnixNano;
    }
    if (count != null) {
      $result.count = count;
    }
    if (sum != null) {
      $result.sum = sum;
    }
    if (bucketCounts != null) {
      $result.bucketCounts.addAll(bucketCounts);
    }
    if (explicitBounds != null) {
      $result.explicitBounds.addAll(explicitBounds);
    }
    if (exemplars != null) {
      $result.exemplars.addAll(exemplars);
    }
    if (attributes != null) {
      $result.attributes.addAll(attributes);
    }
    if (flags != null) {
      $result.flags = flags;
    }
    if (min != null) {
      $result.min = min;
    }
    if (max != null) {
      $result.max = max;
    }
    return $result;
  }
  HistogramDataPoint._() : super();
  factory HistogramDataPoint.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory HistogramDataPoint.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HistogramDataPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'startTimeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'count', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'sum', $pb.PbFieldType.OD)
    ..p<$fixnum.Int64>(
        6, _omitFieldNames ? '' : 'bucketCounts', $pb.PbFieldType.KF6)
    ..p<$core.double>(
        7, _omitFieldNames ? '' : 'explicitBounds', $pb.PbFieldType.KD)
    ..pc<Exemplar>(8, _omitFieldNames ? '' : 'exemplars', $pb.PbFieldType.PM,
        subBuilder: Exemplar.create)
    ..pc<$3.KeyValue>(
        9, _omitFieldNames ? '' : 'attributes', $pb.PbFieldType.PM,
        subBuilder: $3.KeyValue.create)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'flags', $pb.PbFieldType.OU3)
    ..a<$core.double>(11, _omitFieldNames ? '' : 'min', $pb.PbFieldType.OD)
    ..a<$core.double>(12, _omitFieldNames ? '' : 'max', $pb.PbFieldType.OD)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  HistogramDataPoint clone() => HistogramDataPoint()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  HistogramDataPoint copyWith(void Function(HistogramDataPoint) updates) =>
      super.copyWith((message) => updates(message as HistogramDataPoint))
          as HistogramDataPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HistogramDataPoint create() => HistogramDataPoint._();
  HistogramDataPoint createEmptyInstance() => create();
  static $pb.PbList<HistogramDataPoint> createRepeated() =>
      $pb.PbList<HistogramDataPoint>();
  @$core.pragma('dart2js:noInline')
  static HistogramDataPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HistogramDataPoint>(create);
  static HistogramDataPoint? _defaultInstance;

  ///  StartTimeUnixNano is optional but strongly encouraged, see the
  ///  the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(2)
  $fixnum.Int64 get startTimeUnixNano => $_getI64(0);
  @$pb.TagNumber(2)
  set startTimeUnixNano($fixnum.Int64 v) {
    $_setInt64(0, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStartTimeUnixNano() => $_has(0);
  @$pb.TagNumber(2)
  void clearStartTimeUnixNano() => clearField(2);

  ///  TimeUnixNano is required, see the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(3)
  $fixnum.Int64 get timeUnixNano => $_getI64(1);
  @$pb.TagNumber(3)
  set timeUnixNano($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimeUnixNano() => $_has(1);
  @$pb.TagNumber(3)
  void clearTimeUnixNano() => clearField(3);

  /// count is the number of values in the population. Must be non-negative. This
  /// value must be equal to the sum of the "count" fields in buckets if a
  /// histogram is provided.
  @$pb.TagNumber(4)
  $fixnum.Int64 get count => $_getI64(2);
  @$pb.TagNumber(4)
  set count($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(4)
  void clearCount() => clearField(4);

  ///  sum of the values in the population. If count is zero then this field
  ///  must be zero.
  ///
  ///  Note: Sum should only be filled out when measuring non-negative discrete
  ///  events, and is assumed to be monotonic over the values of these events.
  ///  Negative events *can* be recorded, but sum should not be filled out when
  ///  doing so.  This is specifically to enforce compatibility w/ OpenMetrics,
  ///  see: https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#histogram
  @$pb.TagNumber(5)
  $core.double get sum => $_getN(3);
  @$pb.TagNumber(5)
  set sum($core.double v) {
    $_setDouble(3, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSum() => $_has(3);
  @$pb.TagNumber(5)
  void clearSum() => clearField(5);

  ///  bucket_counts is an optional field contains the count values of histogram
  ///  for each bucket.
  ///
  ///  The sum of the bucket_counts must equal the value in the count field.
  ///
  ///  The number of elements in bucket_counts array must be by one greater than
  ///  the number of elements in explicit_bounds array.
  @$pb.TagNumber(6)
  $core.List<$fixnum.Int64> get bucketCounts => $_getList(4);

  ///  explicit_bounds specifies buckets with explicitly defined bounds for values.
  ///
  ///  The boundaries for bucket at index i are:
  ///
  ///  (-infinity, explicit_bounds[i]] for i == 0
  ///  (explicit_bounds[i-1], explicit_bounds[i]] for 0 < i < size(explicit_bounds)
  ///  (explicit_bounds[i-1], +infinity) for i == size(explicit_bounds)
  ///
  ///  The values in the explicit_bounds array must be strictly increasing.
  ///
  ///  Histogram buckets are inclusive of their upper boundary, except the last
  ///  bucket where the boundary is at infinity. This format is intentionally
  ///  compatible with the OpenMetrics histogram definition.
  @$pb.TagNumber(7)
  $core.List<$core.double> get explicitBounds => $_getList(5);

  /// (Optional) List of exemplars collected from
  /// measurements that were used to form the data point
  @$pb.TagNumber(8)
  $core.List<Exemplar> get exemplars => $_getList(6);

  /// The set of key/value pairs that uniquely identify the timeseries from
  /// where this point belongs. The list may be empty (may contain 0 elements).
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  @$pb.TagNumber(9)
  $core.List<$3.KeyValue> get attributes => $_getList(7);

  /// Flags that apply to this specific data point.  See DataPointFlags
  /// for the available flags and their meaning.
  @$pb.TagNumber(10)
  $core.int get flags => $_getIZ(8);
  @$pb.TagNumber(10)
  set flags($core.int v) {
    $_setUnsignedInt32(8, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasFlags() => $_has(8);
  @$pb.TagNumber(10)
  void clearFlags() => clearField(10);

  /// min is the minimum value over (start_time, end_time].
  @$pb.TagNumber(11)
  $core.double get min => $_getN(9);
  @$pb.TagNumber(11)
  set min($core.double v) {
    $_setDouble(9, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasMin() => $_has(9);
  @$pb.TagNumber(11)
  void clearMin() => clearField(11);

  /// max is the maximum value over (start_time, end_time].
  @$pb.TagNumber(12)
  $core.double get max => $_getN(10);
  @$pb.TagNumber(12)
  set max($core.double v) {
    $_setDouble(10, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasMax() => $_has(10);
  @$pb.TagNumber(12)
  void clearMax() => clearField(12);
}

/// Buckets are a set of bucket counts, encoded in a contiguous array
/// of counts.
class ExponentialHistogramDataPoint_Buckets extends $pb.GeneratedMessage {
  factory ExponentialHistogramDataPoint_Buckets({
    $core.int? offset,
    $core.Iterable<$fixnum.Int64>? bucketCounts,
  }) {
    final $result = create();
    if (offset != null) {
      $result.offset = offset;
    }
    if (bucketCounts != null) {
      $result.bucketCounts.addAll(bucketCounts);
    }
    return $result;
  }
  ExponentialHistogramDataPoint_Buckets._() : super();
  factory ExponentialHistogramDataPoint_Buckets.fromBuffer(
          $core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ExponentialHistogramDataPoint_Buckets.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExponentialHistogramDataPoint.Buckets',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.OS3)
    ..p<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'bucketCounts', $pb.PbFieldType.KU6)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ExponentialHistogramDataPoint_Buckets clone() =>
      ExponentialHistogramDataPoint_Buckets()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ExponentialHistogramDataPoint_Buckets copyWith(
          void Function(ExponentialHistogramDataPoint_Buckets) updates) =>
      super.copyWith((message) =>
              updates(message as ExponentialHistogramDataPoint_Buckets))
          as ExponentialHistogramDataPoint_Buckets;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExponentialHistogramDataPoint_Buckets create() =>
      ExponentialHistogramDataPoint_Buckets._();
  ExponentialHistogramDataPoint_Buckets createEmptyInstance() => create();
  static $pb.PbList<ExponentialHistogramDataPoint_Buckets> createRepeated() =>
      $pb.PbList<ExponentialHistogramDataPoint_Buckets>();
  @$core.pragma('dart2js:noInline')
  static ExponentialHistogramDataPoint_Buckets getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          ExponentialHistogramDataPoint_Buckets>(create);
  static ExponentialHistogramDataPoint_Buckets? _defaultInstance;

  /// Offset is the bucket index of the first entry in the bucket_counts array.
  ///
  /// Note: This uses a varint encoding as a simple form of compression.
  @$pb.TagNumber(1)
  $core.int get offset => $_getIZ(0);
  @$pb.TagNumber(1)
  set offset($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasOffset() => $_has(0);
  @$pb.TagNumber(1)
  void clearOffset() => clearField(1);

  ///  bucket_counts is an array of count values, where bucket_counts[i] carries
  ///  the count of the bucket at index (offset+i). bucket_counts[i] is the count
  ///  of values greater than base^(offset+i) and less than or equal to
  ///  base^(offset+i+1).
  ///
  ///  Note: By contrast, the explicit HistogramDataPoint uses
  ///  fixed64.  This field is expected to have many buckets,
  ///  especially zeros, so uint64 has been selected to ensure
  ///  varint encoding.
  @$pb.TagNumber(2)
  $core.List<$fixnum.Int64> get bucketCounts => $_getList(1);
}

///  ExponentialHistogramDataPoint is a single data point in a timeseries that describes the
///  time-varying values of a ExponentialHistogram of double values. A ExponentialHistogram contains
///  summary statistics for a population of values, it may optionally contain the
///  distribution of those values across a set of buckets.
class ExponentialHistogramDataPoint extends $pb.GeneratedMessage {
  factory ExponentialHistogramDataPoint({
    $core.Iterable<$3.KeyValue>? attributes,
    $fixnum.Int64? startTimeUnixNano,
    $fixnum.Int64? timeUnixNano,
    $fixnum.Int64? count,
    $core.double? sum,
    $core.int? scale,
    $fixnum.Int64? zeroCount,
    ExponentialHistogramDataPoint_Buckets? positive,
    ExponentialHistogramDataPoint_Buckets? negative,
    $core.int? flags,
    $core.Iterable<Exemplar>? exemplars,
    $core.double? min,
    $core.double? max,
    $core.double? zeroThreshold,
  }) {
    final $result = create();
    if (attributes != null) {
      $result.attributes.addAll(attributes);
    }
    if (startTimeUnixNano != null) {
      $result.startTimeUnixNano = startTimeUnixNano;
    }
    if (timeUnixNano != null) {
      $result.timeUnixNano = timeUnixNano;
    }
    if (count != null) {
      $result.count = count;
    }
    if (sum != null) {
      $result.sum = sum;
    }
    if (scale != null) {
      $result.scale = scale;
    }
    if (zeroCount != null) {
      $result.zeroCount = zeroCount;
    }
    if (positive != null) {
      $result.positive = positive;
    }
    if (negative != null) {
      $result.negative = negative;
    }
    if (flags != null) {
      $result.flags = flags;
    }
    if (exemplars != null) {
      $result.exemplars.addAll(exemplars);
    }
    if (min != null) {
      $result.min = min;
    }
    if (max != null) {
      $result.max = max;
    }
    if (zeroThreshold != null) {
      $result.zeroThreshold = zeroThreshold;
    }
    return $result;
  }
  ExponentialHistogramDataPoint._() : super();
  factory ExponentialHistogramDataPoint.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ExponentialHistogramDataPoint.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExponentialHistogramDataPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..pc<$3.KeyValue>(
        1, _omitFieldNames ? '' : 'attributes', $pb.PbFieldType.PM,
        subBuilder: $3.KeyValue.create)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'startTimeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'count', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'sum', $pb.PbFieldType.OD)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'scale', $pb.PbFieldType.OS3)
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'zeroCount', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<ExponentialHistogramDataPoint_Buckets>(
        8, _omitFieldNames ? '' : 'positive',
        subBuilder: ExponentialHistogramDataPoint_Buckets.create)
    ..aOM<ExponentialHistogramDataPoint_Buckets>(
        9, _omitFieldNames ? '' : 'negative',
        subBuilder: ExponentialHistogramDataPoint_Buckets.create)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'flags', $pb.PbFieldType.OU3)
    ..pc<Exemplar>(11, _omitFieldNames ? '' : 'exemplars', $pb.PbFieldType.PM,
        subBuilder: Exemplar.create)
    ..a<$core.double>(12, _omitFieldNames ? '' : 'min', $pb.PbFieldType.OD)
    ..a<$core.double>(13, _omitFieldNames ? '' : 'max', $pb.PbFieldType.OD)
    ..a<$core.double>(
        14, _omitFieldNames ? '' : 'zeroThreshold', $pb.PbFieldType.OD)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ExponentialHistogramDataPoint clone() =>
      ExponentialHistogramDataPoint()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ExponentialHistogramDataPoint copyWith(
          void Function(ExponentialHistogramDataPoint) updates) =>
      super.copyWith(
              (message) => updates(message as ExponentialHistogramDataPoint))
          as ExponentialHistogramDataPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExponentialHistogramDataPoint create() =>
      ExponentialHistogramDataPoint._();
  ExponentialHistogramDataPoint createEmptyInstance() => create();
  static $pb.PbList<ExponentialHistogramDataPoint> createRepeated() =>
      $pb.PbList<ExponentialHistogramDataPoint>();
  @$core.pragma('dart2js:noInline')
  static ExponentialHistogramDataPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExponentialHistogramDataPoint>(create);
  static ExponentialHistogramDataPoint? _defaultInstance;

  /// The set of key/value pairs that uniquely identify the timeseries from
  /// where this point belongs. The list may be empty (may contain 0 elements).
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  @$pb.TagNumber(1)
  $core.List<$3.KeyValue> get attributes => $_getList(0);

  ///  StartTimeUnixNano is optional but strongly encouraged, see the
  ///  the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(2)
  $fixnum.Int64 get startTimeUnixNano => $_getI64(1);
  @$pb.TagNumber(2)
  set startTimeUnixNano($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStartTimeUnixNano() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartTimeUnixNano() => clearField(2);

  ///  TimeUnixNano is required, see the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(3)
  $fixnum.Int64 get timeUnixNano => $_getI64(2);
  @$pb.TagNumber(3)
  set timeUnixNano($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimeUnixNano() => $_has(2);
  @$pb.TagNumber(3)
  void clearTimeUnixNano() => clearField(3);

  /// count is the number of values in the population. Must be
  /// non-negative. This value must be equal to the sum of the "bucket_counts"
  /// values in the positive and negative Buckets plus the "zero_count" field.
  @$pb.TagNumber(4)
  $fixnum.Int64 get count => $_getI64(3);
  @$pb.TagNumber(4)
  set count($fixnum.Int64 v) {
    $_setInt64(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearCount() => clearField(4);

  ///  sum of the values in the population. If count is zero then this field
  ///  must be zero.
  ///
  ///  Note: Sum should only be filled out when measuring non-negative discrete
  ///  events, and is assumed to be monotonic over the values of these events.
  ///  Negative events *can* be recorded, but sum should not be filled out when
  ///  doing so.  This is specifically to enforce compatibility w/ OpenMetrics,
  ///  see: https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#histogram
  @$pb.TagNumber(5)
  $core.double get sum => $_getN(4);
  @$pb.TagNumber(5)
  set sum($core.double v) {
    $_setDouble(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSum() => $_has(4);
  @$pb.TagNumber(5)
  void clearSum() => clearField(5);

  ///  scale describes the resolution of the histogram.  Boundaries are
  ///  located at powers of the base, where:
  ///
  ///    base = (2^(2^-scale))
  ///
  ///  The histogram bucket identified by `index`, a signed integer,
  ///  contains values that are greater than (base^index) and
  ///  less than or equal to (base^(index+1)).
  ///
  ///  The positive and negative ranges of the histogram are expressed
  ///  separately.  Negative values are mapped by their absolute value
  ///  into the negative range using the same scale as the positive range.
  ///
  ///  scale is not restricted by the protocol, as the permissible
  ///  values depend on the range of the data.
  @$pb.TagNumber(6)
  $core.int get scale => $_getIZ(5);
  @$pb.TagNumber(6)
  set scale($core.int v) {
    $_setSignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasScale() => $_has(5);
  @$pb.TagNumber(6)
  void clearScale() => clearField(6);

  ///  zero_count is the count of values that are either exactly zero or
  ///  within the region considered zero by the instrumentation at the
  ///  tolerated degree of precision.  This bucket stores values that
  ///  cannot be expressed using the standard exponential formula as
  ///  well as values that have been rounded to zero.
  ///
  ///  Implementations MAY consider the zero bucket to have probability
  ///  mass equal to (zero_count / count).
  @$pb.TagNumber(7)
  $fixnum.Int64 get zeroCount => $_getI64(6);
  @$pb.TagNumber(7)
  set zeroCount($fixnum.Int64 v) {
    $_setInt64(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasZeroCount() => $_has(6);
  @$pb.TagNumber(7)
  void clearZeroCount() => clearField(7);

  /// positive carries the positive range of exponential bucket counts.
  @$pb.TagNumber(8)
  ExponentialHistogramDataPoint_Buckets get positive => $_getN(7);
  @$pb.TagNumber(8)
  set positive(ExponentialHistogramDataPoint_Buckets v) {
    setField(8, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasPositive() => $_has(7);
  @$pb.TagNumber(8)
  void clearPositive() => clearField(8);
  @$pb.TagNumber(8)
  ExponentialHistogramDataPoint_Buckets ensurePositive() => $_ensure(7);

  /// negative carries the negative range of exponential bucket counts.
  @$pb.TagNumber(9)
  ExponentialHistogramDataPoint_Buckets get negative => $_getN(8);
  @$pb.TagNumber(9)
  set negative(ExponentialHistogramDataPoint_Buckets v) {
    setField(9, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasNegative() => $_has(8);
  @$pb.TagNumber(9)
  void clearNegative() => clearField(9);
  @$pb.TagNumber(9)
  ExponentialHistogramDataPoint_Buckets ensureNegative() => $_ensure(8);

  /// Flags that apply to this specific data point.  See DataPointFlags
  /// for the available flags and their meaning.
  @$pb.TagNumber(10)
  $core.int get flags => $_getIZ(9);
  @$pb.TagNumber(10)
  set flags($core.int v) {
    $_setUnsignedInt32(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasFlags() => $_has(9);
  @$pb.TagNumber(10)
  void clearFlags() => clearField(10);

  /// (Optional) List of exemplars collected from
  /// measurements that were used to form the data point
  @$pb.TagNumber(11)
  $core.List<Exemplar> get exemplars => $_getList(10);

  /// min is the minimum value over (start_time, end_time].
  @$pb.TagNumber(12)
  $core.double get min => $_getN(11);
  @$pb.TagNumber(12)
  set min($core.double v) {
    $_setDouble(11, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasMin() => $_has(11);
  @$pb.TagNumber(12)
  void clearMin() => clearField(12);

  /// max is the maximum value over (start_time, end_time].
  @$pb.TagNumber(13)
  $core.double get max => $_getN(12);
  @$pb.TagNumber(13)
  set max($core.double v) {
    $_setDouble(12, v);
  }

  @$pb.TagNumber(13)
  $core.bool hasMax() => $_has(12);
  @$pb.TagNumber(13)
  void clearMax() => clearField(13);

  /// ZeroThreshold may be optionally set to convey the width of the zero
  /// region. Where the zero region is defined as the closed interval
  /// [-ZeroThreshold, ZeroThreshold].
  /// When ZeroThreshold is 0, zero count bucket stores values that cannot be
  /// expressed using the standard exponential formula as well as values that
  /// have been rounded to zero.
  @$pb.TagNumber(14)
  $core.double get zeroThreshold => $_getN(13);
  @$pb.TagNumber(14)
  set zeroThreshold($core.double v) {
    $_setDouble(13, v);
  }

  @$pb.TagNumber(14)
  $core.bool hasZeroThreshold() => $_has(13);
  @$pb.TagNumber(14)
  void clearZeroThreshold() => clearField(14);
}

///  Represents the value at a given quantile of a distribution.
///
///  To record Min and Max values following conventions are used:
///  - The 1.0 quantile is equivalent to the maximum value observed.
///  - The 0.0 quantile is equivalent to the minimum value observed.
///
///  See the following issue for more context:
///  https://github.com/open-telemetry/opentelemetry-proto/issues/125
class SummaryDataPoint_ValueAtQuantile extends $pb.GeneratedMessage {
  factory SummaryDataPoint_ValueAtQuantile({
    $core.double? quantile,
    $core.double? value,
  }) {
    final $result = create();
    if (quantile != null) {
      $result.quantile = quantile;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  SummaryDataPoint_ValueAtQuantile._() : super();
  factory SummaryDataPoint_ValueAtQuantile.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SummaryDataPoint_ValueAtQuantile.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SummaryDataPoint.ValueAtQuantile',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..a<$core.double>(1, _omitFieldNames ? '' : 'quantile', $pb.PbFieldType.OD)
    ..a<$core.double>(2, _omitFieldNames ? '' : 'value', $pb.PbFieldType.OD)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SummaryDataPoint_ValueAtQuantile clone() =>
      SummaryDataPoint_ValueAtQuantile()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SummaryDataPoint_ValueAtQuantile copyWith(
          void Function(SummaryDataPoint_ValueAtQuantile) updates) =>
      super.copyWith(
              (message) => updates(message as SummaryDataPoint_ValueAtQuantile))
          as SummaryDataPoint_ValueAtQuantile;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SummaryDataPoint_ValueAtQuantile create() =>
      SummaryDataPoint_ValueAtQuantile._();
  SummaryDataPoint_ValueAtQuantile createEmptyInstance() => create();
  static $pb.PbList<SummaryDataPoint_ValueAtQuantile> createRepeated() =>
      $pb.PbList<SummaryDataPoint_ValueAtQuantile>();
  @$core.pragma('dart2js:noInline')
  static SummaryDataPoint_ValueAtQuantile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SummaryDataPoint_ValueAtQuantile>(
          create);
  static SummaryDataPoint_ValueAtQuantile? _defaultInstance;

  /// The quantile of a distribution. Must be in the interval
  /// [0.0, 1.0].
  @$pb.TagNumber(1)
  $core.double get quantile => $_getN(0);
  @$pb.TagNumber(1)
  set quantile($core.double v) {
    $_setDouble(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasQuantile() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuantile() => clearField(1);

  ///  The value at the given quantile of a distribution.
  ///
  ///  Quantile values must NOT be negative.
  @$pb.TagNumber(2)
  $core.double get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

/// SummaryDataPoint is a single data point in a timeseries that describes the
/// time-varying values of a Summary metric.
class SummaryDataPoint extends $pb.GeneratedMessage {
  factory SummaryDataPoint({
    $fixnum.Int64? startTimeUnixNano,
    $fixnum.Int64? timeUnixNano,
    $fixnum.Int64? count,
    $core.double? sum,
    $core.Iterable<SummaryDataPoint_ValueAtQuantile>? quantileValues,
    $core.Iterable<$3.KeyValue>? attributes,
    $core.int? flags,
  }) {
    final $result = create();
    if (startTimeUnixNano != null) {
      $result.startTimeUnixNano = startTimeUnixNano;
    }
    if (timeUnixNano != null) {
      $result.timeUnixNano = timeUnixNano;
    }
    if (count != null) {
      $result.count = count;
    }
    if (sum != null) {
      $result.sum = sum;
    }
    if (quantileValues != null) {
      $result.quantileValues.addAll(quantileValues);
    }
    if (attributes != null) {
      $result.attributes.addAll(attributes);
    }
    if (flags != null) {
      $result.flags = flags;
    }
    return $result;
  }
  SummaryDataPoint._() : super();
  factory SummaryDataPoint.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SummaryDataPoint.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SummaryDataPoint',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'startTimeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(4, _omitFieldNames ? '' : 'count', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'sum', $pb.PbFieldType.OD)
    ..pc<SummaryDataPoint_ValueAtQuantile>(
        6, _omitFieldNames ? '' : 'quantileValues', $pb.PbFieldType.PM,
        subBuilder: SummaryDataPoint_ValueAtQuantile.create)
    ..pc<$3.KeyValue>(
        7, _omitFieldNames ? '' : 'attributes', $pb.PbFieldType.PM,
        subBuilder: $3.KeyValue.create)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'flags', $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SummaryDataPoint clone() => SummaryDataPoint()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SummaryDataPoint copyWith(void Function(SummaryDataPoint) updates) =>
      super.copyWith((message) => updates(message as SummaryDataPoint))
          as SummaryDataPoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SummaryDataPoint create() => SummaryDataPoint._();
  SummaryDataPoint createEmptyInstance() => create();
  static $pb.PbList<SummaryDataPoint> createRepeated() =>
      $pb.PbList<SummaryDataPoint>();
  @$core.pragma('dart2js:noInline')
  static SummaryDataPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SummaryDataPoint>(create);
  static SummaryDataPoint? _defaultInstance;

  ///  StartTimeUnixNano is optional but strongly encouraged, see the
  ///  the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(2)
  $fixnum.Int64 get startTimeUnixNano => $_getI64(0);
  @$pb.TagNumber(2)
  set startTimeUnixNano($fixnum.Int64 v) {
    $_setInt64(0, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasStartTimeUnixNano() => $_has(0);
  @$pb.TagNumber(2)
  void clearStartTimeUnixNano() => clearField(2);

  ///  TimeUnixNano is required, see the detailed comments above Metric.
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(3)
  $fixnum.Int64 get timeUnixNano => $_getI64(1);
  @$pb.TagNumber(3)
  set timeUnixNano($fixnum.Int64 v) {
    $_setInt64(1, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasTimeUnixNano() => $_has(1);
  @$pb.TagNumber(3)
  void clearTimeUnixNano() => clearField(3);

  /// count is the number of values in the population. Must be non-negative.
  @$pb.TagNumber(4)
  $fixnum.Int64 get count => $_getI64(2);
  @$pb.TagNumber(4)
  set count($fixnum.Int64 v) {
    $_setInt64(2, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(2);
  @$pb.TagNumber(4)
  void clearCount() => clearField(4);

  ///  sum of the values in the population. If count is zero then this field
  ///  must be zero.
  ///
  ///  Note: Sum should only be filled out when measuring non-negative discrete
  ///  events, and is assumed to be monotonic over the values of these events.
  ///  Negative events *can* be recorded, but sum should not be filled out when
  ///  doing so.  This is specifically to enforce compatibility w/ OpenMetrics,
  ///  see: https://github.com/OpenObservability/OpenMetrics/blob/main/specification/OpenMetrics.md#summary
  @$pb.TagNumber(5)
  $core.double get sum => $_getN(3);
  @$pb.TagNumber(5)
  set sum($core.double v) {
    $_setDouble(3, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSum() => $_has(3);
  @$pb.TagNumber(5)
  void clearSum() => clearField(5);

  /// (Optional) list of values at different quantiles of the distribution calculated
  /// from the current snapshot. The quantiles must be strictly increasing.
  @$pb.TagNumber(6)
  $core.List<SummaryDataPoint_ValueAtQuantile> get quantileValues =>
      $_getList(4);

  /// The set of key/value pairs that uniquely identify the timeseries from
  /// where this point belongs. The list may be empty (may contain 0 elements).
  /// Attribute keys MUST be unique (it is not allowed to have more than one
  /// attribute with the same key).
  @$pb.TagNumber(7)
  $core.List<$3.KeyValue> get attributes => $_getList(5);

  /// Flags that apply to this specific data point.  See DataPointFlags
  /// for the available flags and their meaning.
  @$pb.TagNumber(8)
  $core.int get flags => $_getIZ(6);
  @$pb.TagNumber(8)
  set flags($core.int v) {
    $_setUnsignedInt32(6, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasFlags() => $_has(6);
  @$pb.TagNumber(8)
  void clearFlags() => clearField(8);
}

enum Exemplar_Value { asDouble, asInt, notSet }

/// A representation of an exemplar, which is a sample input measurement.
/// Exemplars also hold information about the environment when the measurement
/// was recorded, for example the span and trace ID of the active span when the
/// exemplar was recorded.
class Exemplar extends $pb.GeneratedMessage {
  factory Exemplar({
    $fixnum.Int64? timeUnixNano,
    $core.double? asDouble,
    $core.List<$core.int>? spanId,
    $core.List<$core.int>? traceId,
    $fixnum.Int64? asInt,
    $core.Iterable<$3.KeyValue>? filteredAttributes,
  }) {
    final $result = create();
    if (timeUnixNano != null) {
      $result.timeUnixNano = timeUnixNano;
    }
    if (asDouble != null) {
      $result.asDouble = asDouble;
    }
    if (spanId != null) {
      $result.spanId = spanId;
    }
    if (traceId != null) {
      $result.traceId = traceId;
    }
    if (asInt != null) {
      $result.asInt = asInt;
    }
    if (filteredAttributes != null) {
      $result.filteredAttributes.addAll(filteredAttributes);
    }
    return $result;
  }
  Exemplar._() : super();
  factory Exemplar.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Exemplar.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static const $core.Map<$core.int, Exemplar_Value> _Exemplar_ValueByTag = {
    3: Exemplar_Value.asDouble,
    6: Exemplar_Value.asInt,
    0: Exemplar_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Exemplar',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'opentelemetry.proto.metrics.v1'),
      createEmptyInstance: create)
    ..oo(0, [3, 6])
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'timeUnixNano', $pb.PbFieldType.OF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'asDouble', $pb.PbFieldType.OD)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'spanId', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'traceId', $pb.PbFieldType.OY)
    ..a<$fixnum.Int64>(6, _omitFieldNames ? '' : 'asInt', $pb.PbFieldType.OSF6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..pc<$3.KeyValue>(
        7, _omitFieldNames ? '' : 'filteredAttributes', $pb.PbFieldType.PM,
        subBuilder: $3.KeyValue.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Exemplar clone() => Exemplar()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Exemplar copyWith(void Function(Exemplar) updates) =>
      super.copyWith((message) => updates(message as Exemplar)) as Exemplar;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Exemplar create() => Exemplar._();
  Exemplar createEmptyInstance() => create();
  static $pb.PbList<Exemplar> createRepeated() => $pb.PbList<Exemplar>();
  @$core.pragma('dart2js:noInline')
  static Exemplar getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Exemplar>(create);
  static Exemplar? _defaultInstance;

  Exemplar_Value whichValue() => _Exemplar_ValueByTag[$_whichOneof(0)]!;
  void clearValue() => clearField($_whichOneof(0));

  ///  time_unix_nano is the exact time when this exemplar was recorded
  ///
  ///  Value is UNIX Epoch time in nanoseconds since 00:00:00 UTC on 1 January
  ///  1970.
  @$pb.TagNumber(2)
  $fixnum.Int64 get timeUnixNano => $_getI64(0);
  @$pb.TagNumber(2)
  set timeUnixNano($fixnum.Int64 v) {
    $_setInt64(0, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasTimeUnixNano() => $_has(0);
  @$pb.TagNumber(2)
  void clearTimeUnixNano() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get asDouble => $_getN(1);
  @$pb.TagNumber(3)
  set asDouble($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasAsDouble() => $_has(1);
  @$pb.TagNumber(3)
  void clearAsDouble() => clearField(3);

  /// (Optional) Span ID of the exemplar trace.
  /// span_id may be missing if the measurement is not recorded inside a trace
  /// or if the trace is not sampled.
  @$pb.TagNumber(4)
  $core.List<$core.int> get spanId => $_getN(2);
  @$pb.TagNumber(4)
  set spanId($core.List<$core.int> v) {
    $_setBytes(2, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSpanId() => $_has(2);
  @$pb.TagNumber(4)
  void clearSpanId() => clearField(4);

  /// (Optional) Trace ID of the exemplar trace.
  /// trace_id may be missing if the measurement is not recorded inside a trace
  /// or if the trace is not sampled.
  @$pb.TagNumber(5)
  $core.List<$core.int> get traceId => $_getN(3);
  @$pb.TagNumber(5)
  set traceId($core.List<$core.int> v) {
    $_setBytes(3, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasTraceId() => $_has(3);
  @$pb.TagNumber(5)
  void clearTraceId() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get asInt => $_getI64(4);
  @$pb.TagNumber(6)
  set asInt($fixnum.Int64 v) {
    $_setInt64(4, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasAsInt() => $_has(4);
  @$pb.TagNumber(6)
  void clearAsInt() => clearField(6);

  /// The set of key/value pairs that were filtered out by the aggregator, but
  /// recorded alongside the original measurement. Only key/value pairs that were
  /// filtered out by the aggregator should be included
  @$pb.TagNumber(7)
  $core.List<$3.KeyValue> get filteredAttributes => $_getList(5);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
