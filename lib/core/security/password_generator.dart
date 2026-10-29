import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum PasswordStrength {
  weak('Weak', 0.25, AppColors.error),
  fair('Fair', 0.50, Colors.orange),
  good('Good', 0.75, Colors.blue),
  strong('Strong', 1.0, AppColors.success);

  final String label;
  final double score;
  final Color color;

  const PasswordStrength(this.label, this.score, this.color);
}

class PasswordGeneratorOptions {
  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeNumbers;
  final bool includeSpecial;

  const PasswordGeneratorOptions({
    this.length = 16,
    this.includeUppercase = true,
    this.includeLowercase = true,
    this.includeNumbers = true,
    this.includeSpecial = true,
  });

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? includeUppercase,
    bool? includeLowercase,
    bool? includeNumbers,
    bool? includeSpecial,
  }) {
    return PasswordGeneratorOptions(
      length: length ?? this.length,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeNumbers: includeNumbers ?? this.includeNumbers,
      includeSpecial: includeSpecial ?? this.includeSpecial,
    );
  }
}

class PasswordGenerator {
  static const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String numberChars = '0123456789';
  static const String specialChars = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  final Random _random;

  PasswordGenerator({Random? random}) : _random = random ?? Random.secure();

  /// Generates a cryptographically strong, unbiased random password
  String generate([PasswordGeneratorOptions options = const PasswordGeneratorOptions()]) {
    final length = options.length.clamp(8, 64);

    final pools = <String>[];
    if (options.includeUppercase) pools.add(uppercaseChars);
    if (options.includeLowercase) pools.add(lowercaseChars);
    if (options.includeNumbers) pools.add(numberChars);
    if (options.includeSpecial) pools.add(specialChars);

    // Fallback if all options were unchecked
    if (pools.isEmpty) {
      pools.add(lowercaseChars);
      pools.add(uppercaseChars);
    }

    final chars = <String>[];

    // Ensure at least one character from each selected pool
    for (final pool in pools) {
      chars.add(_selectRandomChar(pool));
    }

    // Fill the remainder from the combined pool
    final combinedPool = pools.join();
    while (chars.length < length) {
      chars.add(_selectRandomChar(combinedPool));
    }

    // Cryptographic Fisher-Yates shuffle to eliminate any predictable positioning
    for (int i = chars.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }

    return chars.join();
  }

  /// Selects a character without modulo bias
  String _selectRandomChar(String pool) {
    if (pool.isEmpty) return '';
    final index = _random.nextInt(pool.length);
    return pool[index];
  }

  /// Evaluates password strength based on length, complexity, and character variety
  static PasswordStrength calculateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 14) score++;
    if (password.length >= 18) score++;

    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()_\-+=\[\]{}|;:,.<>?]').hasMatch(password)) score++;

    if (score >= 6) {
      return PasswordStrength.strong;
    } else if (score >= 4) {
      return PasswordStrength.good;
    } else if (score >= 3) {
      return PasswordStrength.fair;
    } else {
      return PasswordStrength.weak;
    }
  }
}
