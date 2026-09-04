class ValidationResult {
  const ValidationResult({this.isValid = true, this.errors = const []});

  final bool isValid;
  final List<String> errors;

  static const valid = ValidationResult();
}

class NameValidator {
  static const maxLength = 100;

  static ValidationResult validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        errors: ['الاسم مطلوب'],
      );
    }

    final trimmed = value.trim();
    final errors = <String>[];

    if (trimmed.length > maxLength) {
      errors.add('الاسم يجب أن يكون $maxLength حرف أو أقل');
    }

    if (trimmed.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'))) {
      errors.add('الاسم يحتوي على أحرف غير مسموحة');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

class QuantityValidator {
  static ValidationResult validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        errors: ['الكمية مطلوبة'],
      );
    }

    final number = int.tryParse(value.trim());
    if (number == null) {
      return const ValidationResult(
        isValid: false,
        errors: ['الكمية يجب أن تكون رقماً صحيحاً'],
      );
    }

    if (number < 0) {
      return const ValidationResult(
        isValid: false,
        errors: ['الكمية يجب أن تكون أكبر من أو تساوي صفر'],
      );
    }

    return ValidationResult.valid;
  }
}

class NotesValidator {
  static const maxLength = 500;

  static ValidationResult validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.valid;
    }

    final trimmed = value.trim();
    final errors = <String>[];

    if (trimmed.length > maxLength) {
      errors.add('الملاحظات يجب أن تكون $maxLength حرف أو أقل');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}

class LaptopValidator {
  static ValidationResult validate({
    int? brandId,
    int? modelId,
    int? cpuId,
    int? gpuId,
    int? screenId,
    String? quantity,
    String? notes,
  }) {
    final errors = <String>[];

    if (brandId == null) errors.add('الشركة مطلوبة');
    if (modelId == null) errors.add('الموديل مطلوب');
    if (cpuId == null) errors.add('المعالج مطلوب');
    if (gpuId == null) errors.add('كرت الشاشة مطلوب');
    if (screenId == null) errors.add('حجم الشاشة مطلوب');

    final quantityResult = QuantityValidator.validate(quantity);
    if (!quantityResult.isValid) {
      errors.addAll(quantityResult.errors);
    }

    final notesResult = NotesValidator.validate(notes);
    if (!notesResult.isValid) {
      errors.addAll(notesResult.errors);
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
