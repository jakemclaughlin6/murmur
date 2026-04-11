/// JSON codec for the [Block] sealed hierarchy.
///
/// Discriminator field: `type` with values `paragraph`, `heading`, `image`,
/// `blockquote`, `list_item`.
///
/// TDD RED stub: intentionally incomplete. Filled in during GREEN step.
library;

import 'block.dart';

extension BlockJson on Block {
  Map<String, dynamic> toJson() =>
      throw UnimplementedError('BlockJson.toJson not yet implemented');
}

Block blockFromJson(Map<String, dynamic> json) =>
    throw UnimplementedError('blockFromJson not yet implemented');

List<Block> blocksFromJsonString(String jsonString) =>
    throw UnimplementedError('blocksFromJsonString not yet implemented');

String blocksToJsonString(List<Block> blocks) =>
    throw UnimplementedError('blocksToJsonString not yet implemented');
