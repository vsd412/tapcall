library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../src/contact_manager.dart';
import '../src/open_accessibility_service.dart';
import '../src/function_type.dart';
import '../src/language.dart';
import '../src/translations.dart';
import 'contact_box.dart';
import 'contact_editor_dialog.dart';
import 'reorder_screen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  // Add any state variables here if needed
  final ContactManager _contactManager = ContactManager();
  bool _isLoading = true;
  final PageController _pageController = PageController();

  int _currentPage = 0;
  final List<String> _pageTitles = [
    "(1/?) Welcome to TapCall!",
    "(2/?) Enable Android Settings",
    "(3/?) Connect to ESP32 Controller",
    "(4/?) Setting Contacts",
    "(5/?) Setting Extra Functions",
    "(6/?) All Done!",
  ];

  final List<Widget> _pages = [
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Align(alignment: Alignment.centerLeft, child: Text(
            'TapCall allows you to call your family and friends with a single press.',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.info, size: 120, color: Colors.blue),
        ],
      ),),
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Align(alignment: Alignment.centerLeft, child: Text(
            'TapCall requires bluetooth, accessibility and location services.\nTo setup...',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.settings, size: 120, color: Colors.orange),
        ],
      ),),
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Align(alignment: Alignment.centerLeft,child: Text(
            'You can use the physical TapCall Controller via Bluetooth.',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.gamepad, size: 120, color: Colors.green),
        ],
      ),),
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Align(alignment: Alignment.centerLeft, child: Text(
            'To setup a contact, press Add More Contacts button.',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.phone, size: 120, color: Colors.blue),
        ],
      ),),
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
        Align(alignment: Alignment.centerLeft, child: Text(
            'TapCall can also ......\nTo setup extra functions, press Add More Extra Functions button.',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.lock_clock, size: 120, color: Colors.orange),
        ],
      ),),
    Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Align(alignment: Alignment.centerLeft,child: Text(
            'You can view this guide later in the Settings page.',
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 16, color: Colors.white,),
          ),),
          SizedBox(height: 24),
          Icon(Icons.info, size: 120, color: Colors.green),
        ],
      ),),
  ];

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      setState(() {
        _currentPage++;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTranslations();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTranslations() async {
    return;
  }

  Future<void> _loadSettings() async {
    // Load slots, language preferences, system nav mode, and SOS contact
    await _contactManager.loadContacts();

    // Load language preferences
    final language = await Language.getLanguage();
    final uiLanguage = await Language.getUILanguage();

    // Load SOS contact
    final sosContact = await _contactManager.getSOSContact();

    // Collect all slots that have contacts stored
    List<Contact?> loadedContacts = [];
    List<int> loadedSlotNumbers = [];

    for (int slot = 1; slot <= 100; slot++) {
      final contact = _contactManager.getContact(slot);
      if (contact != null) {
        loadedContacts.add(contact);
        loadedSlotNumbers.add(slot);
      }
    }

    setState(() {
      _isLoading = false;
      _loadTranslations();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 35, 40, 50),
        title: const Text('Information',style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,),),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white,),
          onPressed: () => Navigator.pop(context),
        ),
      ),


      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2C3E50),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3498DB), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pageTitles[_currentPage],
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _pages[index];
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: GestureDetector(
                  onTap: _previousPage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _currentPage > 0
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _currentPage > 0 ? Colors.white : Colors.white30,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: _currentPage > 0 ? Colors.white : Colors.white30,
                      size: 50,
                    ),
                  ),
                ),),

                const SizedBox(width: 20),

                Expanded(child: GestureDetector(
                  onTap: _currentPage < _pages.length - 1 ? _nextPage : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _currentPage < _pages.length - 1
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _currentPage < _pages.length - 1 ? Colors.white : Colors.white30,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: _currentPage < _pages.length - 1 ? Colors.white : Colors.white30,
                      size: 50,
                    ),
                  ),
                ),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
