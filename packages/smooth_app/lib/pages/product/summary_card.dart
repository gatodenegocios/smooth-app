import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:openfoodfacts/model/Attribute.dart';
import 'package:openfoodfacts/model/AttributeGroup.dart';
import 'package:openfoodfacts/model/Product.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/cards/data_cards/score_card.dart';
import 'package:smooth_app/cards/expandables/attribute_list_expandable.dart';
import 'package:smooth_app/data_models/product_preferences.dart';
import 'package:smooth_app/helpers/attributes_card_helper.dart';
import 'package:smooth_app/helpers/product_cards_helper.dart';
import 'package:smooth_app/helpers/product_compatibility_helper.dart';
import 'package:smooth_app/helpers/score_card_helper.dart';
import 'package:smooth_ui_library/smooth_ui_library.dart';
import 'package:smooth_ui_library/util/ui_helpers.dart';

const List<String> _SCORE_ATTRIBUTE_IDS = <String>[
  Attribute.ATTRIBUTE_NUTRISCORE,
  Attribute.ATTRIBUTE_ECOSCORE
];

const List<String> _ATTRIBUTE_GROUP_ORDER = <String>[
  AttributeGroup.ATTRIBUTE_GROUP_ALLERGENS,
  AttributeGroup.ATTRIBUTE_GROUP_INGREDIENT_ANALYSIS,
  AttributeGroup.ATTRIBUTE_GROUP_PROCESSING,
  AttributeGroup.ATTRIBUTE_GROUP_NUTRITIONAL_QUALITY,
  AttributeGroup.ATTRIBUTE_GROUP_LABELS,
];

class SummaryCard extends StatelessWidget {
  // TODO(jasmeet): Change the signature to
  //    SummaryCard({ required this.product, required this.productPreferences });
  const SummaryCard(this._product, this._productPreferences);

  final Product _product;
  final ProductPreferences _productPreferences;

  @override
  Widget build(BuildContext context) {
    final List<Attribute> scoreAttributes =
        AttributeListExpandable.getPopulatedAttributes(
            _product, _SCORE_ATTRIBUTE_IDS);

    final List<AttributeGroup> attributeGroupsToBeRendered =
        _getAttributeGroupsToBeRendered();
    final Widget attributesContainer = Container(
      alignment: Alignment.topLeft,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: <Widget>[
          for (final AttributeGroup group in attributeGroupsToBeRendered)
            _buildAttributeGroup(
              context,
              group,
              group == attributeGroupsToBeRendered.first,
            ),
        ],
      ),
    );

    return buildProductSmoothCard(
      header: _buildProductCompatibilityHeader(context),
      body: Padding(
        padding: SMOOTH_CARD_PADDING,
        child: Column(
          children: <Widget>[
            _buildProductTitleTile(context),
            for (final Attribute attribute in scoreAttributes)
              ScoreCard(
                iconUrl: attribute.iconUrl!,
                description:
                    attribute.descriptionShort ?? attribute.description!,
                cardEvaluation: getCardEvaluationFromAttribute(attribute),
              ),
            attributesContainer,
          ],
        ),
      ),
    );
  }

  List<AttributeGroup> _getAttributeGroupsToBeRendered() {
    final List<AttributeGroup> attributeGroupsToBeRendered = <AttributeGroup>[];
    for (final String groupId in _ATTRIBUTE_GROUP_ORDER) {
      final Iterable<AttributeGroup> groupIterable = _product.attributeGroups!
          .where((AttributeGroup group) => group.id == groupId);
      if (groupIterable.isEmpty) {
        continue;
      }
      final AttributeGroup group = groupIterable.single;

      final bool containsImportantAttributes = group.attributes!.any(
          (Attribute attribute) =>
              _productPreferences.isAttributeImportant(attribute.id!) == true);
      if (containsImportantAttributes) {
        attributeGroupsToBeRendered.add(group);
      }
    }
    return attributeGroupsToBeRendered;
  }

  Widget _buildProductCompatibilityHeader(BuildContext context) {
    final ProductCompatibility compatibility =
        getProductCompatibility(_productPreferences, _product);
    // NOTE: This is temporary and will be updated once the feature is supported
    // by the server.
    return Container(
      decoration: BoxDecoration(
        color: getProductCompatibilityHeaderBackgroundColor(compatibility),
        // Ensure that the header has the same circular radius as the SmoothCard.
        borderRadius: const BorderRadius.only(
          topLeft: SmoothCard.CIRCULAR_RADIUS,
          topRight: SmoothCard.CIRCULAR_RADIUS,
        ),
      ),
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.symmetric(vertical: SMALL_SPACE),
      child: Center(
        child: Text(
          getProductCompatibilityHeaderTextWidget(compatibility),
          style:
              Theme.of(context).textTheme.subtitle1!.apply(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProductTitleTile(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context)!;
    final ThemeData themeData = Theme.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          getProductName(_product, appLocalizations),
          style: themeData.textTheme.headline4,
        ),
        subtitle: Text(_product.brands ?? appLocalizations.unknownBrand),
        trailing: Text(
          _product.quantity ?? '',
          style: themeData.textTheme.headline3,
        ),
      ),
    );
  }

  /// Builds an AttributeGroup, if [isFirstGroup] is true the group doesn't get
  /// a divider header.
  Widget _buildAttributeGroup(
    BuildContext context,
    AttributeGroup group,
    bool isFirstGroup,
  ) {
    final List<Widget> attributeChips = <Widget>[];
    for (final Attribute attribute in group.attributes!) {
      final Widget? attributeChip = _buildAttributeChipForValidAttributes(
        attribute: attribute,
        returnNullIfStatusUnknown:
            group.id == AttributeGroup.ATTRIBUTE_GROUP_LABELS,
      );
      if (attributeChip != null) {
        attributeChips.add(attributeChip);
      }
    }
    if (attributeChips.isEmpty) {
      return EMPTY_WIDGET;
    }
    return Column(
      children: <Widget>[
        _buildAttributeGroupHeader(context, group, isFirstGroup),
        Container(
          alignment: Alignment.topLeft,
          child: Wrap(
            runSpacing: 16,
            children: attributeChips,
          ),
        ),
      ],
    );
  }

  /// The attribute group header can either be group name or a divider depending
  /// upon the type of the group.
  Widget _buildAttributeGroupHeader(
    BuildContext context,
    AttributeGroup group,
    bool isFirstGroup,
  ) {
    if (group.id == AttributeGroup.ATTRIBUTE_GROUP_ALLERGENS) {
      return Container(
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.only(top: SMALL_SPACE, bottom: LARGE_SPACE),
        child: Text(
          group.name!,
          style:
              Theme.of(context).textTheme.bodyText2!.apply(color: Colors.grey),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SMALL_SPACE),
      child: isFirstGroup
          ? EMPTY_WIDGET
          : const Divider(
              color: Colors.black12,
            ),
    );
  }

  Widget? _buildAttributeChipForValidAttributes({
    required Attribute attribute,
    required bool returnNullIfStatusUnknown,
  }) {
    if (attribute.id == null || _SCORE_ATTRIBUTE_IDS.contains(attribute.id)) {
      // Score Attribute Ids have already been rendered.
      return null;
    }
    if (_productPreferences.isAttributeImportant(attribute.id!) != true) {
      // Not an important attribute.
      return null;
    }
    if (returnNullIfStatusUnknown &&
        attribute.status == Attribute.STATUS_UNKNOWN) {
      return null;
    }
    final String? attributeDisplayTitle = getDisplayTitle(attribute);
    final Widget attributeIcon = getAttributeDisplayIcon(attribute);
    if (attributeDisplayTitle == null) {
      return null;
    }
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return SizedBox(
          width: constraints.maxWidth / 2,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                attributeIcon,
                Expanded(
                    child: Text(
                  attributeDisplayTitle,
                )),
              ]));
    });
  }
}