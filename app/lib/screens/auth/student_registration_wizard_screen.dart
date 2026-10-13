import 'package:flutter/material.dart';
import '../profile_account/edit_profile_screen.dart';

class StudentRegistrationWizardScreen extends StatelessWidget {
  final VoidCallback? onFinished;
  const StudentRegistrationWizardScreen({super.key, this.onFinished});
  @override
  Widget build(BuildContext context) => EditProfileScreen(onSaved: onFinished);
}
