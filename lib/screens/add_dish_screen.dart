import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/dish_availability.dart';
import '../models/seller_addon.dart';
import '../models/seller_dish.dart';
import '../models/seller_dish_category.dart';
import '../models/seller_super_category.dart';
import '../seller_session_prefs.dart';
import '../services/optica2_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_toast.dart';

/// Multi-step add dish: details → availability → pricing → photos.
class AddDishScreen extends StatefulWidget {
  const AddDishScreen({
    super.key,
    required this.phoneE164,
    this.editDish,
    this.initialStep = 0,
  }) : assert(initialStep >= 0 && initialStep <= 3);

  final String phoneE164;
  final SellerDish? editDish;
  final int initialStep;

  @override
  State<AddDishScreen> createState() => _AddDishScreenState();
}

class _AddDishScreenState extends State<AddDishScreen> {
  late final PageController _pageController;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _api = Optica2Api();
  final _picker = ImagePicker();

  int _step = 0;
  DishDiscountType _discountType = DishDiscountType.none;
  bool _isVeg = true;
  final List<XFile> _images = [];
  List<String> _existingImageUrls = [];
  late DishAvailabilitySchedule _availability;
  List<SellerAddon> _kitchenAddons = [];
  final Set<int> _selectedAddonIds = {};
  bool _loadingAddons = true;
  List<SellerSuperCategory> _superCategories = [];
  bool _loadingSuperCategories = true;
  List<SellerDishCategory> _dishCategories = [];
  int? _selectedDishCategoryId;
  int? _selectedDishSubcategoryId;
  bool _loadingDishCategories = true;
  bool _submitting = false;

  static const _steps = ['Details', 'Availability', 'Pricing', 'Photos'];

  bool get _isEdit => widget.editDish != null;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, 3);
    _pageController = PageController(initialPage: _step);
    final dish = widget.editDish;
    if (dish != null) {
      _nameController.text = dish.name;
      _descriptionController.text = dish.description ?? '';
      _ingredientsController.text = dish.ingredients ?? '';
      _tagsController.text = dish.tagsLabel;
      _priceController.text = dish.price.toStringAsFixed(
        dish.price.truncateToDouble() == dish.price ? 0 : 2,
      );
      _discountType = dish.discountType;
      if (dish.discountValue != null) {
        _discountController.text = dish.discountValue!.toStringAsFixed(
          dish.discountValue!.truncateToDouble() == dish.discountValue! ? 0 : 2,
        );
      }
      _isVeg = dish.isVeg;
      _existingImageUrls = List<String>.from(dish.imageUrls);
      _availability = DishAvailabilitySchedule.fromApi(dish.availability);
      _selectedAddonIds.addAll(dish.addonIds);
      _selectedDishCategoryId = dish.dishCategoryId;
      _selectedDishSubcategoryId = dish.dishSubcategoryId;
    } else {
      _availability = DishAvailabilitySchedule.defaults();
    }
    _loadKitchenAddons();
    _loadSuperCategories();
    _loadDishCategories();
  }

  Future<void> _loadDishCategories() async {
    try {
      final categories = await _api.fetchDishCategories();
      if (!mounted) return;
      setState(() {
        _dishCategories = categories;
        _loadingDishCategories = false;
        if (_selectedDishCategoryId != null &&
            !categories.any((c) => c.id == _selectedDishCategoryId)) {
          _selectedDishCategoryId = null;
          _selectedDishSubcategoryId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDishCategories = false);
    }
  }

  void _selectDishCategory(int categoryId) {
    setState(() {
      if (_selectedDishCategoryId == categoryId) return;
      _selectedDishCategoryId = categoryId;
      _selectedDishSubcategoryId = null;
    });
  }

  void _selectDishSubcategory(int subcategoryId) {
    setState(() => _selectedDishSubcategoryId = subcategoryId);
  }

  List<SellerDishSubcategory> get _selectedCategorySubcategories {
    if (_selectedDishCategoryId == null) return const [];
    for (final category in _dishCategories) {
      if (category.id == _selectedDishCategoryId) {
        return category.subcategories;
      }
    }
    return const [];
  }

  Future<void> _loadSuperCategories() async {
    try {
      final categories = await _api.fetchSuperCategories();
      if (!mounted) return;
      setState(() {
        _superCategories = categories;
        _loadingSuperCategories = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSuperCategories = false);
    }
  }

  Future<void> _loadKitchenAddons() async {
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final addons = await _api.fetchAddons(
        phoneE164: widget.phoneE164,
        sellerId: sellerId,
      );
      if (!mounted) return;
      setState(() {
        _kitchenAddons = addons;
        _loadingAddons = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddons = false);
    }
  }

  void _toggleAddon(int id) {
    setState(() {
      if (_selectedAddonIds.contains(id)) {
        _selectedAddonIds.remove(id);
      } else {
        _selectedAddonIds.add(id);
      }
    });
  }

  List<int> get _superCategoryIdsForApi {
    final ids = _superCategoryIdsFromSchedule(_availability, _superCategories);
    ids.sort();
    return ids;
  }

  List<int> get _selectedAddonIdsList =>
      _selectedAddonIds.toList()..sort();

  @override
  void dispose() {
    _api.close();
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = AppColors.brandPurple.withValues(alpha: 0.28);
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.exo2(
        color: AppColors.deepGreen.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.brandPurple, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _pickImages() async {
    if (kIsWeb) {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 88,
      );
      if (file != null && _images.length < 5) {
        setState(() => _images.add(file));
      }
      return;
    }

    final files = await _picker.pickMultiImage(
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (files.isEmpty) return;
    setState(() {
      for (final file in files) {
        if (_images.length >= 5) break;
        _images.add(file);
      }
    });
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          AppToast.warning(context, 'Enter the dish name.');
          return false;
        }
        if (_loadingDishCategories) {
          AppToast.warning(context, 'Loading categories…');
          return false;
        }
        if (_dishCategories.isEmpty) {
          AppToast.warning(
            context,
            'No categories available. Ask admin to add them.',
          );
          return false;
        }
        if (_selectedDishCategoryId == null) {
          AppToast.warning(context, 'Select a category (e.g. Biryani).');
          return false;
        }
        if (_selectedDishSubcategoryId == null) {
          AppToast.warning(
            context,
            'Select a sub category (e.g. Chicken Biryani).',
          );
          return false;
        }
        return true;
      case 1:
        if (_loadingSuperCategories) {
          AppToast.warning(context, 'Loading sub categories…');
          return false;
        }
        if (_superCategories.isEmpty) {
          AppToast.warning(
            context,
            'No sub categories available. Ask admin to add them.',
          );
          return false;
        }
        if (!_availability.hasAnySlotEnabled) {
          AppToast.warning(
            context,
            'Turn on at least one sub category for any day.',
          );
          return false;
        }
        if (_superCategoryIdsForApi.isEmpty) {
          AppToast.warning(
            context,
            'Sub categories must match meal slots (Breakfast, Lunch, etc.).',
          );
          return false;
        }
        return true;
      case 2:
        final price = double.tryParse(_priceController.text.trim());
        if (price == null || price <= 0) {
          AppToast.warning(context, 'Enter a valid price.');
          return false;
        }
        if (_discountType != DishDiscountType.none) {
          final discount = double.tryParse(_discountController.text.trim());
          if (discount == null || discount <= 0) {
            AppToast.warning(context, 'Enter a valid discount.');
            return false;
          }
          if (_discountType == DishDiscountType.percent && discount > 100) {
            AppToast.warning(context, 'Discount cannot exceed 100%.');
            return false;
          }
          if (_discountType == DishDiscountType.amount && discount >= price) {
            AppToast.warning(
              context,
              'Discount amount must be less than the price.',
            );
            return false;
          }
        }
        return true;
      case 3:
        if (_images.isEmpty && _existingImageUrls.isEmpty) {
          AppToast.warning(context, 'Add at least one photo.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 3) {
      _goToStep(_step + 1);
      return;
    }
    _submit();
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    _goToStep(_step - 1);
  }

  void _goToStep(int index) {
    if (index == _step || index < 0 || index >= _steps.length) return;
    setState(() => _step = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;

    setState(() => _submitting = true);
    try {
      final sellerId = await SellerSessionPrefs.sellerId();
      final price = double.parse(_priceController.text.trim());
      double? discountValue;
      if (_discountType != DishDiscountType.none) {
        discountValue = double.parse(_discountController.text.trim());
      }

      if (_isEdit) {
        await _api.updateDish(
          phoneE164: widget.phoneE164,
          dishId: widget.editDish!.id,
          superCategoryIds: _superCategoryIdsForApi,
          dishCategoryId: _selectedDishCategoryId!,
          dishSubcategoryId: _selectedDishSubcategoryId!,
          sellerId: sellerId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          ingredients: _ingredientsController.text.trim().isEmpty
              ? null
              : _ingredientsController.text.trim(),
          tags: _tagsController.text.trim().isEmpty
              ? null
              : _tagsController.text.trim(),
          availabilityJson: _availability.toApiJsonString(),
          price: price,
          discountType: _discountType,
          discountValue: discountValue,
          isVeg: _isVeg,
          images: List<XFile>.from(_images),
          addonIds: _selectedAddonIdsList,
        );
      } else {
        await _api.createDish(
          phoneE164: widget.phoneE164,
          superCategoryIds: _superCategoryIdsForApi,
          dishCategoryId: _selectedDishCategoryId!,
          dishSubcategoryId: _selectedDishSubcategoryId!,
          sellerId: sellerId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          ingredients: _ingredientsController.text.trim().isEmpty
              ? null
              : _ingredientsController.text.trim(),
          tags: _tagsController.text.trim().isEmpty
              ? null
              : _tagsController.text.trim(),
          availabilityJson: _availability.toApiJsonString(),
          price: price,
          discountType: _discountType,
          discountValue: discountValue,
          isVeg: _isVeg,
          images: List<XFile>.from(_images),
          addonIds: _selectedAddonIdsList,
        );
      }

      if (!mounted) return;
      AppToast.success(
        context,
        _isEdit ? 'Dish updated.' : 'Dish added to your menu.',
      );
      Navigator.of(context).pop(true);
    } on Optica2ApiException catch (e) {
      if (!mounted) return;
      AppToast.danger(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.danger(context, 'Could not save dish. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.deepGreen),
          onPressed: _submitting ? null : _back,
        ),
        title: Text(
          widget.initialStep == 1 && _isEdit
              ? 'Availability'
              : _isEdit
                  ? 'Edit dish'
                  : 'Add dish',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: _StepIndicator(
              current: _step,
              labels: _steps,
              onStepTap: _submitting ? null : _goToStep,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _DetailsStep(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  ingredientsController: _ingredientsController,
                  tagsController: _tagsController,
                  isVeg: _isVeg,
                  onVegChanged: (v) => setState(() => _isVeg = v),
                  decoration: _fieldDecoration,
                  addons: _kitchenAddons,
                  loadingAddons: _loadingAddons,
                  selectedAddonIds: _selectedAddonIds,
                  onAddonToggle: _toggleAddon,
                  dishCategories: _dishCategories,
                  loadingDishCategories: _loadingDishCategories,
                  selectedDishCategoryId: _selectedDishCategoryId,
                  selectedDishSubcategoryId: _selectedDishSubcategoryId,
                  subcategories: _selectedCategorySubcategories,
                  onDishCategorySelected: _selectDishCategory,
                  onDishSubcategorySelected: _selectDishSubcategory,
                ),
                _AvailabilityStep(
                  schedule: _availability,
                  superCategories: _superCategories,
                  loadingSuperCategories: _loadingSuperCategories,
                  onChanged: () => setState(() {}),
                ),
                _PricingStep(
                  priceController: _priceController,
                  discountController: _discountController,
                  discountType: _discountType,
                  onDiscountTypeChanged: (t) => setState(() {
                    _discountType = t;
                    if (t == DishDiscountType.none) {
                      _discountController.clear();
                    }
                  }),
                  decoration: _fieldDecoration,
                ),
                _PhotosStep(
                  images: _images,
                  existingImageUrls: _existingImageUrls,
                  onAdd: _pickImages,
                  onRemove: _removeImage,
                  onRemoveExisting: (index) => setState(
                    () => _existingImageUrls.removeAt(index),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _submitting ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPurple,
                    disabledBackgroundColor:
                        AppColors.brandPurple.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step < 3
                              ? 'Continue'
                              : (_isEdit ? 'Save changes' : 'Save dish'),
                          style: GoogleFonts.exo2(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.current,
    required this.labels,
    this.onStepTap,
  });

  final int current;
  final List<String> labels;
  final ValueChanged<int>? onStepTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final reached = i <= current;
        final selected = i == current;
        final tappable = onStepTap != null;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: tappable ? () => onStepTap!(i) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.brandPurple
                                  : reached
                                      ? AppColors.brandPurple
                                          .withValues(alpha: 0.55)
                                      : AppColors.brandPurple
                                          .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : reached
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                              color: selected
                                  ? AppColors.brandPurple
                                  : reached
                                      ? AppColors.deepGreen
                                      : AppColors.deepGreen
                                          .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (i < labels.length - 1) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.nameController,
    required this.descriptionController,
    required this.ingredientsController,
    required this.tagsController,
    required this.isVeg,
    required this.onVegChanged,
    required this.decoration,
    required this.addons,
    required this.loadingAddons,
    required this.selectedAddonIds,
    required this.onAddonToggle,
    required this.dishCategories,
    required this.loadingDishCategories,
    required this.selectedDishCategoryId,
    required this.selectedDishSubcategoryId,
    required this.subcategories,
    required this.onDishCategorySelected,
    required this.onDishSubcategorySelected,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController ingredientsController;
  final TextEditingController tagsController;
  final bool isVeg;
  final ValueChanged<bool> onVegChanged;
  final InputDecoration Function(String hint) decoration;
  final List<SellerAddon> addons;
  final bool loadingAddons;
  final Set<int> selectedAddonIds;
  final ValueChanged<int> onAddonToggle;
  final List<SellerDishCategory> dishCategories;
  final bool loadingDishCategories;
  final int? selectedDishCategoryId;
  final int? selectedDishSubcategoryId;
  final List<SellerDishSubcategory> subcategories;
  final ValueChanged<int> onDishCategorySelected;
  final ValueChanged<int> onDishSubcategorySelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          'Food details',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Name and description customers will see on your menu.',
          style: GoogleFonts.exo2(
            fontSize: 14,
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Dish name',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: decoration('e.g. Paneer Butter Masala'),
          style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Text(
          'Category',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        if (loadingDishCategories)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPurple,
                ),
              ),
            ),
          )
        else
          DropdownButtonFormField<int>(
            key: ValueKey<int?>(selectedDishCategoryId),
            initialValue: dishCategories.any(
              (category) => category.id == selectedDishCategoryId,
            )
                ? selectedDishCategoryId
                : null,
            decoration: decoration('Select category'),
            hint: Text(
              dishCategories.isEmpty
                  ? 'No categories available'
                  : 'Select category',
              style: GoogleFonts.exo2(),
            ),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              color: AppColors.deepGreen,
            ),
            items: dishCategories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(
                      category.name,
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
                .toList(),
            onChanged: dishCategories.isEmpty
                ? null
                : (value) {
                    if (value != null) onDishCategorySelected(value);
                  },
          ),
        const SizedBox(height: 16),
        Text(
          'Sub category',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey<Object?>(
            '$selectedDishCategoryId-$selectedDishSubcategoryId',
          ),
          initialValue: subcategories.any(
            (sub) => sub.id == selectedDishSubcategoryId,
          )
              ? selectedDishSubcategoryId
              : null,
          decoration: decoration('Select sub category'),
          hint: Text(
            selectedDishCategoryId == null
                ? 'Select category first'
                : subcategories.isEmpty
                    ? 'No sub categories available'
                    : 'Select sub category',
            style: GoogleFonts.exo2(),
          ),
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w600,
            color: AppColors.deepGreen,
          ),
          items: subcategories
              .map(
                (sub) => DropdownMenuItem(
                  value: sub.id,
                  child: Text(
                    sub.name,
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
          onChanged: selectedDishCategoryId == null || subcategories.isEmpty
              ? null
              : (value) {
                  if (value != null) onDishSubcategorySelected(value);
                },
        ),
        const SizedBox(height: 16),
        Text(
          'Description',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          maxLines: 3,
          decoration: decoration('Short summary for customers…'),
          style: GoogleFonts.exo2(),
        ),
        const SizedBox(height: 16),
        Text(
          'Ingredients',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ingredientsController,
          maxLines: 4,
          decoration: decoration('e.g. paneer, butter, tomatoes, cream, spices…'),
          style: GoogleFonts.exo2(),
        ),
        const SizedBox(height: 16),
        Text(
          'Tags',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Separate with commas — helps customers find your dish.',
          style: GoogleFonts.exo2(
            fontSize: 12,
            color: AppColors.deepGreen.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: tagsController,
          textCapitalization: TextCapitalization.words,
          decoration: decoration('e.g. spicy, bestseller, gluten-free'),
          style: GoogleFonts.exo2(),
        ),
        const SizedBox(height: 20),
        Text(
          'Add-ons',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select extras customers can add to this dish (optional).',
          style: GoogleFonts.exo2(
            fontSize: 12,
            color: AppColors.deepGreen.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        if (loadingAddons)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPurple,
                ),
              ),
            ),
          )
        else if (addons.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.terracotta.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'No add-ons yet. Create them from Kitchen → Add-on.',
              style: GoogleFonts.exo2(
                fontSize: 12,
                height: 1.4,
                color: AppColors.deepGreen.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: addons.map((addon) {
              final selected = selectedAddonIds.contains(addon.id);
              return FilterChip(
                label: Text(
                  '${addon.name} · ${addon.priceLabel}',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.deepGreen,
                  ),
                ),
                selected: selected,
                showCheckmark: true,
                checkmarkColor: Colors.white,
                onSelected: (_) => onAddonToggle(addon.id),
                selectedColor: AppColors.terracotta,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? AppColors.terracotta
                      : AppColors.terracotta.withValues(alpha: 0.35),
                ),
                avatar: selected
                    ? null
                    : Icon(
                        Icons.add_box_outlined,
                        size: 18,
                        color: AppColors.terracotta.withValues(alpha: 0.7),
                      ),
              );
            }).toList(),
          ),
        if (selectedAddonIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${selectedAddonIds.length} add-on${selectedAddonIds.length == 1 ? '' : 's'} selected',
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brandPurple,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Veg or non-veg',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _VegChoiceChip(
                label: 'Veg',
                icon: Icons.eco_outlined,
                color: AppColors.sage,
                selected: isVeg,
                onTap: () => onVegChanged(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _VegChoiceChip(
                label: 'Non-veg',
                icon: Icons.restaurant_outlined,
                color: AppColors.terracotta,
                selected: !isVeg,
                onTap: () => onVegChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvailabilityStep extends StatelessWidget {
  const _AvailabilityStep({
    required this.schedule,
    required this.superCategories,
    required this.loadingSuperCategories,
    required this.onChanged,
  });

  final DishAvailabilitySchedule schedule;
  final List<SellerSuperCategory> superCategories;
  final bool loadingSuperCategories;
  final VoidCallback onChanged;

  List<SellerSuperCategory> get _scheduleCategories => superCategories
      .where((c) => dishMealKeys.contains(c.mealKey))
      .toList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          'Availability',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'For each day, turn on the sub categories when this dish is offered.',
          style: GoogleFonts.exo2(
            fontSize: 14,
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.65),
          ),
        ),
        if (loadingSuperCategories) ...[
          const SizedBox(height: 24),
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ] else if (_scheduleCategories.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'No sub categories available. Ask admin to add them.',
            style: GoogleFonts.exo2(
              fontSize: 13,
              color: AppColors.terracotta,
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          ...dishDayKeys.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DayAvailabilityCard(
                dayKey: day,
                label: dishDayLabels[day] ?? day,
                schedule: schedule,
                superCategories: _scheduleCategories,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayAvailabilityCard extends StatelessWidget {
  const _DayAvailabilityCard({
    required this.dayKey,
    required this.label,
    required this.schedule,
    required this.superCategories,
    required this.onChanged,
  });

  final String dayKey;
  final String label;
  final DishAvailabilitySchedule schedule;
  final List<SellerSuperCategory> superCategories;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dayOn = schedule.isDayAvailable(dayKey);
    final border = AppColors.brandPurple.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepGreen.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
              ),
              Text(
                'Available',
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepGreen.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: dayOn,
                activeTrackColor: AppColors.brandPurple.withValues(alpha: 0.45),
                activeThumbColor: AppColors.brandPurple,
                onChanged: (value) {
                  schedule.setDayAvailable(dayKey, value);
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Sub categories',
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          ...superCategories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SubCategoryDayToggle(
                category: cat,
                value: schedule.slot(cat.mealKey, dayKey) && dayOn,
                enabled: dayOn,
                onChanged: (v) {
                  schedule.setSlot(cat.mealKey, dayKey, v);
                  onChanged();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubCategoryDayToggle extends StatelessWidget {
  const _SubCategoryDayToggle({
    required this.category,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final SellerSuperCategory category;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final timeRange = category.timeRange.trim();

    return Row(
      children: [
        Icon(
          category.icon,
          size: 20,
          color: enabled
              ? (value
                  ? AppColors.brandPurple
                  : AppColors.deepGreen.withValues(alpha: 0.55))
              : AppColors.deepGreen.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled
                      ? AppColors.deepGreen
                      : AppColors.deepGreen.withValues(alpha: 0.4),
                ),
              ),
              if (timeRange.isNotEmpty)
                Text(
                  timeRange,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    color: AppColors.deepGreen.withValues(
                      alpha: enabled ? 0.5 : 0.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: AppColors.brandPurple.withValues(alpha: 0.45),
          activeThumbColor: AppColors.brandPurple,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Super categories saved when that meal slot is on for any day.
List<int> _superCategoryIdsFromSchedule(
  DishAvailabilitySchedule schedule,
  List<SellerSuperCategory> categories,
) {
  final ids = <int>[];
  for (final cat in categories) {
    final meal = cat.mealKey;
    if (!dishMealKeys.contains(meal)) continue;
    for (final day in dishDayKeys) {
      if (schedule.slot(meal, day)) {
        ids.add(cat.id);
        break;
      }
    }
  }
  return ids;
}

class _VegChoiceChip extends StatelessWidget {
  const _VegChoiceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color
                  : AppColors.brandPurple.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingStep extends StatelessWidget {
  const _PricingStep({
    required this.priceController,
    required this.discountController,
    required this.discountType,
    required this.onDiscountTypeChanged,
    required this.decoration,
  });

  final TextEditingController priceController;
  final TextEditingController discountController;
  final DishDiscountType discountType;
  final ValueChanged<DishDiscountType> onDiscountTypeChanged;
  final InputDecoration Function(String hint) decoration;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          'Price & discount',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Price (₹)',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: decoration('320'),
          style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Text(
          'Discount',
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            color: AppColors.deepGreen.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DishDiscountType.values.map((type) {
            final selected = discountType == type;
            return ChoiceChip(
              label: Text(
                type.label,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.deepGreen,
                ),
              ),
              selected: selected,
              onSelected: (_) => onDiscountTypeChanged(type),
              selectedColor: AppColors.brandPurple,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: AppColors.brandPurple.withValues(alpha: 0.25),
              ),
            );
          }).toList(),
        ),
        if (discountType != DishDiscountType.none) ...[
          const SizedBox(height: 16),
          Text(
            discountType == DishDiscountType.percent
                ? 'Discount (%)'
                : 'Discount amount (₹)',
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: decoration(
              discountType == DishDiscountType.percent ? '10' : '50',
            ),
            style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.images,
    required this.existingImageUrls,
    required this.onAdd,
    required this.onRemove,
    required this.onRemoveExisting,
  });

  final List<XFile> images;
  final List<String> existingImageUrls;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index) onRemoveExisting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          'Photos',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.deepGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add up to 5 photos. The first image is shown first on the menu.',
          style: GoogleFonts.exo2(
            fontSize: 14,
            height: 1.45,
            color: AppColors.deepGreen.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 20),
        if (existingImageUrls.isNotEmpty) ...[
          Text(
            'Current photos',
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: existingImageUrls.length,
            itemBuilder: (context, index) {
              final url = existingImageUrls[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemoveExisting(index),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        if (images.isEmpty && existingImageUrls.isEmpty)
          _AddPhotoButton(onTap: onAdd)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: images.length +
                ((images.length + existingImageUrls.length) < 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < images.length) {
                final file = images[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: kIsWeb
                          ? Image.network(file.path, fit: BoxFit.cover)
                          : Image.file(File(file.path), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(index),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return _AddPhotoButton(onTap: onAdd, compact: true);
            },
          ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: compact ? null : 160,
          padding: compact ? const EdgeInsets.all(20) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandPurple.withValues(alpha: 0.25),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: compact ? 32 : 40,
                color: AppColors.brandPurple,
              ),
              const SizedBox(height: 8),
              Text(
                compact ? 'Add more' : 'Add photos',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
