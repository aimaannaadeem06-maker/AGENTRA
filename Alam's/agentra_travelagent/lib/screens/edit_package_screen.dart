import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/side_navigation.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../services/package_service.dart';
import '../models/package.dart';
import '../config/api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class EditPackageScreen extends StatefulWidget {
  final Package package;
  const EditPackageScreen({Key? key, required this.package}) : super(key: key);

  @override
  State<EditPackageScreen> createState() => _EditPackageScreenState();
}

class _EditPackageScreenState extends State<EditPackageScreen> {
  final _formKey = GlobalKey<FormState>();
  int _selectedNavIndex = 2;

  // Image
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Controllers — pre-filled with existing data
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  List<String> _destinationOptions = ['Lahore', 'Murree'];
  String? _selectedDestination;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _availableSeatsController;
  late TextEditingController _provinceController;
  late TextEditingController _departureCityController;
  late TextEditingController _notIncludedController;
  late TextEditingController _tripHighlightsController;
  late TextEditingController _discountController;
  late TextEditingController _departureTimeController;
  late TextEditingController _departureLocationController;

  // Checkboxes
  late bool _includeTransport;
  late bool _includeAccommodation;
  late bool _includeMeals;
  late bool _isFeatured;
  late bool _hasDiscount;

  // Dates
  DateTime? _startDate;
  DateTime? _endDate;
  late List<DateTime> _availableDates;

  // Itinerary
  late List<Map<String, TextEditingController>> _itineraryDays;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.package;

    // Pre-fill all controllers with existing package data
    _titleController = TextEditingController(text: p.title);
    _descriptionController = TextEditingController(text: p.description);
    _locationController = TextEditingController(text: p.location);
    _priceController = TextEditingController(text: p.price.toString());
    _durationController = TextEditingController(text: p.duration);
    _availableSeatsController =
        TextEditingController(text: p.availableSeats.toString());
    _provinceController = TextEditingController(text: p.province ?? '');
    _departureCityController =
        TextEditingController(text: p.departureCity ?? '');
    _notIncludedController = TextEditingController(text: p.notIncluded ?? '');
    _tripHighlightsController =
        TextEditingController(text: p.tripHighlights ?? '');
    _discountController = TextEditingController(
        text: p.discountPercentage > 0 ? p.discountPercentage.toString() : '');
    _departureTimeController =
        TextEditingController(text: p.departureTime ?? '');
    _departureLocationController =
        TextEditingController(text: p.departureLocation ?? '');
    _selectedDestination = p.location.isNotEmpty ? p.location : null;

    // Pre-fill checkboxes
    _includeTransport = p.includesTransport;
    _includeAccommodation = p.includesAccommodation;
    _includeMeals = p.includesMeals;
    _isFeatured = p.isFeatured;
    _hasDiscount = p.hasDiscount;

    // Pre-fill dates
    _startDate = p.startDate;
    _endDate = p.endDate;
    _availableDates = List.from(p.availableDates);

    // Pre-fill itinerary
    _itineraryDays = p.itinerary.map((day) {
      return {
        'title': TextEditingController(text: day['title'] ?? ''),
        'description': TextEditingController(text: day['description'] ?? ''),
      };
    }).toList();

    // If no itinerary exists, add one empty day
    if (_itineraryDays.isEmpty) _addItineraryDay();
    _loadDestinationOptions();
    _durationController.addListener(_onDurationChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _availableSeatsController.dispose();
    _provinceController.dispose();
    _departureCityController.dispose();
    _notIncludedController.dispose();
    _tripHighlightsController.dispose();
    _discountController.dispose();
    _departureTimeController.dispose();
    _departureLocationController.dispose();
    for (final day in _itineraryDays) {
      day['title']!.dispose();
      day['description']!.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDestinationOptions() async {
    final options = await PackageService.getPackageLocations();
    if (mounted) {
      setState(() {
        _destinationOptions =
            options.isNotEmpty ? options : ['Lahore', 'Murree'];
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    }
  }

  void _addItineraryDay() {
    setState(() {
      _itineraryDays.add({
        'title': TextEditingController(),
        'description': TextEditingController(),
      });
    });
  }

  void _removeItineraryDay(int index) {
    setState(() {
      _itineraryDays[index]['title']!.dispose();
      _itineraryDays[index]['description']!.dispose();
      _itineraryDays.removeAt(index);
    });
  }

  int? _getDurationDays() {
    final text = _durationController.text.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  void _onDurationChanged() {
    if (_startDate == null) return;
    final days = _getDurationDays();
    if (days != null && days > 0) {
      final maxEndDate = _startDate!.add(Duration(days: days));
      if (_endDate == null || _endDate!.isAfter(maxEndDate) || _endDate!.isBefore(_startDate!)) {
        setState(() {
          _endDate = maxEndDate;
        });
      }
    }
  }

  Future<void> _pickStartDate() async {
    final initial = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        final days = _getDurationDays();
        if (days != null && days > 0) {
          _endDate = picked.add(Duration(days: days));
        } else if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Start Date first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final days = _getDurationDays();
    final firstDate = _startDate!;
    final lastDate = (days != null && days > 0)
        ? _startDate!.add(Duration(days: days))
        : _startDate!.add(const Duration(days: 365 * 2));

    DateTime initialDate = _endDate ?? lastDate;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _addAvailableDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _availableDates.add(picked));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Upload new image if selected
      String? imageUrl = widget.package.image;
      if (_selectedImage != null) {
        imageUrl = await PackageService.uploadImage(_selectedImage!);
      }

      final itinerary = _itineraryDays.asMap().entries.map((entry) {
        return {
          'day': entry.key + 1,
          'title': entry.value['title']!.text.trim(),
          'description': entry.value['description']!.text.trim(),
        };
      }).toList();

      final success = await PackageService.updatePackage(
        widget.package.id,
        {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'location': _selectedDestination ?? _locationController.text.trim(),
          'price': double.tryParse(_priceController.text) ?? 0,
          'duration': _durationController.text.trim(),
          'availableSeats': int.tryParse(_availableSeatsController.text) ?? 0,
          'image': imageUrl,
          'province': _provinceController.text.trim(),
          'departureCity': _departureCityController.text.trim(),
          'notIncluded': _notIncludedController.text.trim(),
          'tripHighlights': _tripHighlightsController.text.trim(),
          'includes': {
            'transport': _includeTransport,
            'accommodation': _includeAccommodation,
            'meals': _includeMeals,
          },
          'isFeatured': _isFeatured,
          'hasDiscount': _hasDiscount,
          'discountPercentage': _hasDiscount
              ? (double.tryParse(_discountController.text) ?? 0)
              : 0,
          'startDate': _startDate?.toIso8601String(),
          'endDate': _endDate?.toIso8601String(),
          'availableDates':
              _availableDates.map((d) => d.toIso8601String()).toList(),
          'itinerary': itinerary,
          'departureTime': _departureTimeController.text.trim(),
          'departureLocation': _departureLocationController.text.trim(),
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Package updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update package.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SideNavigation(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (index) {
              setState(() => _selectedNavIndex = index);
            },
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      const Text('Edit Package',
                          style: AppTextStyles.headingMedium),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Thumbnail ──────────────────────────────
                              _buildSection(
                                'Package Thumbnail',
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.radius),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: _imageBytes != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                                AppDimensions.radius),
                                            child: Image.memory(
                                              _imageBytes!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          )
                                        : widget.package.image != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppDimensions.radius),
                                                child: Image.network(
                                                  ApiConfig.getImageUrl(
                                                      widget.package.image!),
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                ),
                                              )
                                            : const Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .cloud_upload_outlined,
                                                        size: 50,
                                                        color: AppColors
                                                            .textTertiary),
                                                    SizedBox(height: 12),
                                                    Text(
                                                        'Click to change image',
                                                        style: AppTextStyles
                                                            .bodyMedium),
                                                    SizedBox(height: 4),
                                                    Text('PNG, JPG up to 5MB',
                                                        style: AppTextStyles
                                                            .bodySmall),
                                                  ],
                                                ),
                                              ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Basic Info ─────────────────────────────
                              _buildSection(
                                'Basic Information',
                                Column(
                                  children: [
                                    CustomInput(
                                      label: 'Package Title',
                                      controller: _titleController,
                                      hint: 'e.g., 2-Day Nathia Gali Adventure',
                                      validator: (v) =>
                                          v!.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 20),
                                    CustomInput(
                                      label: 'Description',
                                      controller: _descriptionController,
                                      hint: 'Describe your package...',
                                      maxLines: 4,
                                      validator: (v) =>
                                          v!.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Destination',
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                value: _selectedDestination,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Select destination',
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppDimensions
                                                                  .radius),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: AppColors
                                                                  .border)),
                                                  enabledBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppDimensions
                                                                  .radius),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: AppColors
                                                                  .border)),
                                                  focusedBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              AppDimensions
                                                                  .radius),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: AppColors
                                                                  .primary,
                                                              width: 2)),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 14),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                                items: _destinationOptions
                                                    .map((destination) =>
                                                        DropdownMenuItem(
                                                            value: destination,
                                                            child: Text(
                                                                destination)))
                                                    .toList(),
                                                onChanged: (value) => setState(
                                                    () => _selectedDestination =
                                                        value),
                                                validator: (value) =>
                                                    value == null
                                                        ? 'Required'
                                                        : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Price (PKR)',
                                            controller: _priceController,
                                            hint: 'e.g., 15000',
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                v!.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Duration',
                                            controller: _durationController,
                                            hint: 'e.g., 3 Days 2 Nights',
                                            validator: (v) =>
                                                v!.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Available Seats',
                                            controller:
                                                _availableSeatsController,
                                            hint: 'e.g., 20',
                                            keyboardType: TextInputType.number,
                                            validator: (v) =>
                                                v!.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Province',
                                            controller: _provinceController,
                                            hint: 'e.g., Khyber Pakhtunkhwa',
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Departure City',
                                            controller:
                                                _departureCityController,
                                            hint: 'e.g., Islamabad',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Departure Time',
                                            controller:
                                                _departureTimeController,
                                            hint: 'e.g., 08:00 AM',
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: CustomInput(
                                            label: 'Departure Location',
                                            controller:
                                                _departureLocationController,
                                            hint: 'e.g., Liberty Chowk, Lahore',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Trip Dates ─────────────────────────────
                              _buildSection(
                                'Trip Dates',
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDatePicker(
                                            label: 'Start Date',
                                            date: _startDate,
                                            onTap: _pickStartDate,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: _buildDatePicker(
                                            label: 'End Date',
                                            date: _endDate,
                                            onTap: _pickEndDate,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Available Departure Dates',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ...List<Widget>.from(_availableDates.map((date) => Chip(
                                              label: Text(_formatDate(date)),
                                              deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 16),
                                              onDeleted: () => setState(() =>
                                                  _availableDates.remove(date)),
                                              backgroundColor: AppColors.primary
                                                  .withOpacity(0.1),
                                              labelStyle: const TextStyle(
                                                  color: AppColors.primary),
                                            ))),
                                        ActionChip(
                                          avatar:
                                              const Icon(Icons.add, size: 16),
                                          label: const Text('Add Date'),
                                          onPressed: _addAvailableDate,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── What's Included ────────────────────────
                              _buildSection(
                                'What\'s Included',
                                Column(
                                  children: [
                                    _buildCheckbox(
                                        'Transport',
                                        _includeTransport,
                                        (v) => setState(
                                            () => _includeTransport = v!)),
                                    _buildCheckbox(
                                        'Accommodation',
                                        _includeAccommodation,
                                        (v) => setState(
                                            () => _includeAccommodation = v!)),
                                    _buildCheckbox(
                                        'Meals',
                                        _includeMeals,
                                        (v) =>
                                            setState(() => _includeMeals = v!)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── What's Not Included ────────────────────
                              _buildSection(
                                'What\'s Not Included',
                                CustomInput(
                                  label: 'Not Included',
                                  controller: _notIncludedController,
                                  hint:
                                      'e.g., Personal expenses, Travel insurance',
                                  maxLines: 3,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Trip Highlights ────────────────────────
                              _buildSection(
                                'Trip Highlights',
                                CustomInput(
                                  label: 'Highlights',
                                  controller: _tripHighlightsController,
                                  hint:
                                      'e.g., Scenic mountain views, Bonfire night',
                                  maxLines: 4,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Daily Itinerary ────────────────────────
                              _buildSection(
                                'Daily Itinerary',
                                Column(
                                  children: [
                                    ..._itineraryDays
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final i = entry.key;
                                      final day = entry.value;
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundLight,
                                          borderRadius: BorderRadius.circular(
                                              AppDimensions.radius),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Day ${i + 1}',
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                if (_itineraryDays.length > 1)
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: AppColors.error),
                                                    onPressed: () =>
                                                        _removeItineraryDay(i),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            CustomInput(
                                              label: 'Day Title',
                                              controller: day['title']!,
                                              hint:
                                                  'e.g., Arrival & Sightseeing',
                                            ),
                                            const SizedBox(height: 12),
                                            CustomInput(
                                              label: 'Activities & Details',
                                              controller: day['description']!,
                                              hint:
                                                  'Describe activities for this day...',
                                              maxLines: 4,
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _addItineraryDay,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Another Day'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppDimensions.radius),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // ── Featured & Discount ────────────────────
                              _buildSection(
                                'Package Tags',
                                Column(
                                  children: [
                                    _buildCheckbox(
                                        'Mark as Featured',
                                        _isFeatured,
                                        (v) =>
                                            setState(() => _isFeatured = v!)),
                                    _buildCheckbox(
                                        'Has Discount',
                                        _hasDiscount,
                                        (v) =>
                                            setState(() => _hasDiscount = v!)),
                                    if (_hasDiscount) ...[
                                      const SizedBox(height: 12),
                                      CustomInput(
                                        label: 'Discount Percentage',
                                        controller: _discountController,
                                        hint: 'e.g., 30',
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                    if (_isFeatured || _hasDiscount) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          if (_isFeatured)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.star,
                                                      color: Colors.white,
                                                      size: 14),
                                                  SizedBox(width: 4),
                                                  Text('Featured',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          if (_isFeatured && _hasDiscount)
                                            const SizedBox(width: 8),
                                          if (_hasDiscount)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.local_offer,
                                                      color: Colors.white,
                                                      size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _discountController
                                                            .text.isEmpty
                                                        ? 'Discount'
                                                        : '${_discountController.text}% OFF',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),

                              // ── Submit ─────────────────────────────────
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        side: const BorderSide(
                                            color: AppColors.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppDimensions.radius),
                                        ),
                                      ),
                                      child: const Text('Cancel',
                                          style: TextStyle(
                                              color: AppColors.textPrimary)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: CustomButton(
                                      text: 'Save Changes',
                                      onPressed: _handleSubmit,
                                      isLoading: _isLoading,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headingSmall.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _buildDatePicker(
      {required String label,
      required DateTime? date,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                Text(
                  date == null ? 'Select date' : _formatDate(date),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: date == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    fontWeight:
                        date == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
