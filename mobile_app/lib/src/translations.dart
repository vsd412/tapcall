/// TapCall Translations
///
/// Purpose:
/// - Provides UI translations and separate TTS phrases for three languages
/// - Simple key→text lookup with template parameter replacement
///
/// Design:
/// - UI uses `UILanguage` maps (`_english`, `_traditionalChinese`, `_simplifiedChinese`)
/// - TTS uses `TTSLanguage` maps (`_ttsEnglish`, `_ttsCantonese`, `_ttsMandarin`)
/// - `get()` and `getTTS()` read current preference and return localized text
library;

import 'package:intl/intl.dart';
import 'language.dart';

class Translations {
  // Get translated text based on current UI language
  static Future<String> get(String key, {Map<String, String>? params}) async {
    final language = await Language.getUILanguage();
    
    String text;
    switch (language) {
      case UILanguage.traditionalChinese:
        text = _traditionalChinese[key] ?? key;
        break;
      case UILanguage.simplifiedChinese:
        text = _simplifiedChinese[key] ?? key;
        break;
      case UILanguage.english:
        text = _english[key] ?? key;
        break;
    }
    
    return _replaceParams(text, params);
  }
  
  // Get TTS announcement based on TTS language (separate from UI language)
  static Future<String> getTTS(String key, {Map<String, String>? params}) async {
    final language = await Language.getLanguage();
    
    String text;
    switch (language) {
      case TTSLanguage.traditionalChinese:
        text = _ttsCantonese[key] ?? key;
        break;
      case TTSLanguage.simplifiedChinese:
        text = _ttsMandarin[key] ?? key;
        break;
      case TTSLanguage.english:
        text = _ttsEnglish[key] ?? key;
        break;
    }
    
    return _replaceParams(text, params);
  }

  static Future<String> getTTS2(String key, {Map<String, String>? params}) async {
    final language = await Language.getLanguage();

    String text;
    switch (language) {
      case TTSLanguage.traditionalChinese:
        text = _traditionalChinese[key] ?? key;
        break;
      case TTSLanguage.simplifiedChinese:
        text = _simplifiedChinese[key] ?? key;
        break;
      case TTSLanguage.english:
        text = _english[key] ?? key;
        break;
    }

    return _replaceParams(text, params);
  }

  // Replace parameters in translated text
  static String _replaceParams(String text, Map<String, String>? params) {
    if (params == null) return text;
    
    String result = text;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
  
  static Future<String> calling(String name) async {
    final template = await getTTS('calling');
    return template.replaceAll('{name}', name);
  }
  
  // Get language-specific time announcement with proper formatting
  static Future<String> getTimeAnnouncement(DateTime now) async {
    final language = await Language.getLanguage();
    
    switch (language) {
      case TTSLanguage.traditionalChinese:
        // Cantonese date/time
        final weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
        final months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
        final weekday = weekdays[now.weekday % 7];
        final month = months[now.month - 1];
        final day = now.day;
        // Convert year to individual digits to prevent wrong pronunciation
        final yearStr = now.year.toString();
        final yearDigits = {'0': '零', '1': '一', '2': '二', '3': '三', '4': '四', '5': '五', '6': '六', '7': '七', '8': '八', '9': '九'};
        final year = yearStr.split('').map((d) => yearDigits[d] ?? d).join('');
        final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final minute = now.minute;
        final period = now.hour >= 12 ? '下午' : '上午';
        return '今日係 $year 年 $month $day 號，$weekday，而家係 $period $hour 點 $minute 分';
        
      case TTSLanguage.simplifiedChinese:
        // Mandarin date/time
        final weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
        final months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
        final weekday = weekdays[now.weekday % 7];
        final month = months[now.month - 1];
        final day = now.day;
        // Convert year to individual digits to prevent wrong pronunciation
        final yearStr = now.year.toString();
        final yearDigits = {'0': '零', '1': '一', '2': '二', '3': '三', '4': '四', '5': '五', '6': '六', '7': '七', '8': '八', '9': '九'};
        final year = yearStr.split('').map((d) => yearDigits[d] ?? d).join('');
        final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final minute = now.minute;
        final period = now.hour >= 12 ? '下午' : '上午';
        return '今天是 $year 年 $month $day 号，$weekday，现在是 $period $hour 点 $minute 分';
        
      case TTSLanguage.english:
        // English date/time
        final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
        final timeFormat = DateFormat('h:mm a');
        final dateStr = dateFormat.format(now);
        final timeStr = timeFormat.format(now);
        return 'Today is $dateStr. The time is $timeStr.';
    }
  }
  
  static Future<String> todayIs(String date, String time) async {
    final language = await Language.getLanguage();
    
    switch (language) {
      case TTSLanguage.traditionalChinese:
        return '今日係 $date，而家係 $time';
      case TTSLanguage.simplifiedChinese:
        return '今天是 $date，现在是 $time';
      case TTSLanguage.english:
        return 'Today is $date. The time is $time.';
    }
  }
  
  // English translations
  static final Map<String, String> _english = {
    // Contact Editor
    'nameMissingReport': 'Please enter the button name.',
    'phoneMissingReport': 'Please enter the phone number.',
    'functionTypeSubtitle': 'FUNCTION TYPE',
    'photoChangeLabel': 'Tap to Change Photo',
    'deleteFunctionLabel': 'Delete',
    'saveFunctionLabel': 'Save',
    'messagingAppSubtitle': 'MESSAGING APP',
    'phoneNumberSubtitle': 'Phone Number',
    'phoneNumberGuide': 'Enter Phone Number',
    'nameChangeSubtitle': 'Label',
    'functionDeleteReport': 'Function deleted!',
    'functionSaveReport': 'Function saved as:',
    'buttonIndexTitle': 'Button',
    'weatherDescription': '📢 Announce the current date and time when pressed.',
    'timeDateDescription': '⛅ Announce the current weather forecast. Location permission required.',
    'nameChangeGuide': 'Enter button label',

    // Settings Screen
    'contactDispName': 'Contact',
    'timeDateDispName': 'Time & Date',
    'weatherDispName': 'Weather',
    'addSOSLabel': 'Add SOS Contact',
    'addContactLabel': 'Add a Contact',
    'addExtraLabel': 'Add an Extra Function',
    'reorderFunctionHover': 'Reorder Functions',
    'uiLanguageTitle': 'UI Language',
    'voLanguageTitle': 'Voice & Subtitles: ',
    'enablePermLabel': 'Enable Phone Permissions',
    'enableAccessLabel': 'Enable Phone Accessibility',
    'enableSetupDescription': '1. Enable Phone & Bluetooth permissions\n2. Enable Phone Accessibility service for auto-calling',
    'enableSetupTitle': 'Required Setup',
    'settingScreenTitle': 'Settings',
    'sosContactTitle': 'SOS Emergency',
    'contactTitle': 'Contacts',
    'extraFunctionTitle': 'Extra Functions',
    'contactPagePrefix': 'Page',
    'sosSetupTitle': 'SOS Contact',
    'sosSetupDescription': 'This contact will be called when the SOS Button is pressed.',
    'sosNameGuide': 'Name',
    'sosPhoneGuide': 'Phone Number',
    'sosDeleteLabel': 'Delete',
    'sosCancelLabel': 'Cancel',
    'sosSaveLabel': 'Save',
    'emptySlotLabel': 'Empty Slot',
    'removeFunctionTitle': 'Remove Button?',
    'removeFunctionDescription': 'This will remove this button permanently!',
    'removeCancelLabel': 'Cancel',
    'removeConfirmLabel': 'Remove',
    'enableAccessReport': 'Enable "TapCall" in Accessibility',
    'sosMissingReport': 'Please enter both name and phone number.',
    'requestPermReport': 'Permissions requested',

    // Reorder Screen
    'reorderScreenTitle': 'Reorder Functions',
    'reorderDiscardTitle': 'Discard Changes?',
    'reorderDiscardDescription': 'You have unsaved changes. Do you want to discard them?',
    'reorderCancelLabel': 'Cancel',
    'reorderDiscardLabel': 'Discard',
    'reorderSaveLabel': 'Save',
    'reorderEmptyTitle': 'No functions added yet',
    'reorderEmptyDescription': 'Add contacts or functions in Settings',
    'reorderScreenDescription': 'Drag each functions to reorder them.',
    
    // SOS Emergency
    'sos_emergency': 'SOS Emergency',
    'sos_description': 'Button 9 will directly call this contact',

    // Contact App Names
    'whatsappDispName': 'Whatsapp',
    'wechatDispName': 'WeChat',

    // Bluetooth Manager
    'bluetoothDeviceTitle': 'Bluetooth Device Manager',
    'bluetoothDeviceScan': 'Scan for Devices',
    'bluetoothDeviceScanning': 'Scanning...',
    'bluetoothDeviceEmpty': 'No devices found.\n\nTap "Scan for Devices" to search,\nor check that your ESP32 is powered on.',
    'bluetoothDeviceUnknown': 'Unknown Device',
    'bluetoothDeviceSignal': 'Signal',
    'bluetoothDeviceClose': 'Close',
    'bluetoothDeviceConnected': 'Connected Device',
    'bluetoothDeviceName': 'Device Name:',

    // Main Call Screen
    'pageNumberPrefix': 'Page',
    'pageNumberSuffix': 'Blank',
    'firstPageWarning': 'Already at first page',
    'lastPageWarning': 'Already at last page',
    'buttonFunctionMissing': 'No function set for this button',
    'buttonPhoneMissing': 'No phone number set for this button',
    'buttonCalling': 'Now Calling',
    'buttonCallFailed': 'Failed to call',
    'buttonSOSMissing': 'The SOS function has not been setup',
    'buttonSOSCalling': 'SOS calling',

    // Notifications
    'callReadyTitle': 'Call Service Active',
    'callReadyDescription': 'Press buttons in the TapCall App to start calling contacts.',
    'deviceConnectedTitle': 'Connected to',
    'deviceConnectedDescription': 'You can use your ESP32 controller for calling.',
  };
  
  // Traditional Chinese (Hong Kong/Taiwan)
  static final Map<String, String> _traditionalChinese = {
    // Contact Editor
    'nameMissingReport': '請輸入按鈕名字。',
    'phoneMissingReport': '請輸入聯絡人電話號碼。',
    'functionTypeSubtitle': '功能類型',
    'photoChangeLabel': '更換照片',
    'deleteFunctionLabel': '刪除',
    'saveFunctionLabel': '儲存',
    'messagingAppSubtitle': '通訊軟件',
    'phoneNumberSubtitle': '電話號碼',
    'phoneNumberGuide': '輸入聯絡人電話號碼',
    'nameChangeSubtitle': '按鈕名字',
    'functionDeleteReport': '已刪除功能！',
    'functionSaveReport': '功能已儲存為：',
    'buttonIndexTitle': '按鈕',
    'weatherDescription': '📢 播放現時日期和時間。',
    'timeDateDescription': '⛅ 播放現時天氣預報。需要位置權限。',
    'nameChangeGuide': '輸入按鈕名字',

    // Settings Screen
    'contactDispName': '聯絡人',
    'timeDateDispName': '時間與日期',
    'weatherDispName': '天氣',
    'addSOSLabel': '新增緊急聯絡人',
    'addContactLabel': '新增聯絡人',
    'addExtraLabel': '新增額外功能',
    'reorderFunctionHover': '更改功能次序',
    'uiLanguageTitle': '介面語言',
    'voLanguageTitle': '語音和字幕：',
    'enablePermLabel': '啟用電話權限',
    'enableAccessLabel': '啟用電話無障礙設定',
    'enableSetupDescription': '1. 啟用電話與藍牙權限\n2. 啟用電話無障礙設定以自動撥號',
    'enableSetupTitle': 'TapCall 所需設定',
    'settingScreenTitle': '設定',
    'sosContactTitle': '緊急求助',
    'contactTitle': '聯絡人',
    'extraFunctionTitle': '額外功能',
    'contactPagePrefix': '頁',
    'sosSetupTitle': '緊急聯絡人',
    'sosSetupDescription': '按下SOS按鈕，致電緊急聯絡人。',
    'sosNameGuide': '聯絡人姓名',
    'sosPhoneGuide': '電話號碼',
    'sosDeleteLabel': '刪除',
    'sosCancelLabel': '取消',
    'sosSaveLabel': '儲存',
    'emptySlotLabel': '未設聯絡人',
    'removeFunctionTitle': '移除按鈕？',
    'removeFunctionDescription': '這將永久移除此按鈕！',
    'removeCancelLabel': '取消',
    'removeConfirmLabel': '移除',
    'enableAccessReport': '在無障礙設定中啟用「TapCall」',
    'sosMissingReport': '請輸入姓名和電話號碼。',
    'requestPermReport': '已請求電話權限',

    // Reorder Screen
    'reorderScreenTitle': '更改功能次序',
    'reorderDiscardTitle': '放棄更改？',
    'reorderDiscardDescription': '您尚未儲存功能次序。是否放棄更改？',
    'reorderCancelLabel': '取消',
    'reorderDiscardLabel': '放棄',
    'reorderSaveLabel': '儲存',
    'reorderEmptyTitle': '尚未設定功能',
    'reorderEmptyDescription': '在設定頁面中，新增聯絡人或功能',
    'reorderScreenDescription': '拖曳各功能更改次序。',

    // Main Screen
    'ble_connected': '藍牙已連接',
    'ble_disconnected': '藍牙未連接',
    'accessibility_required': '需要無障礙服務',
    'location_required_weather': '需要位置權限',
    'page_indicator': '{current}/{total}',
    'hold_settings': '長按進入設定',
    'no_contacts_yet': '未有聯絡人',
    'add_contacts_message': '在設定中新增聯絡人以開始通話',
    'open_settings': '開啟設定',
    
    // SOS Emergency
    'sos_emergency': '緊急求救',
    'sos_description': '按第 9 號按鈕會直接打電話俾呢個聯絡人',

    // Contact App Names
    'whatsappDispName': 'Whatsapp',
    'wechatDispName': '微信',

    // Bluetooth Manager
    'bluetoothDeviceTitle': '管理藍牙裝置',
    'bluetoothDeviceScan': '搜尋藍牙裝置',
    'bluetoothDeviceScanning': '搜尋中...',
    'bluetoothDeviceEmpty': '未找到藍牙裝置。\n\n請按「搜尋藍牙裝置」按鈕，\n或檢查你的 ESP32 是否已啟動。',
    'bluetoothDeviceUnknown': '不明裝置',
    'bluetoothDeviceSignal': '訊號',
    'bluetoothDeviceClose': '返回',
    'bluetoothDeviceConnected': '已連接裝置',
    'bluetoothDeviceName': '裝置名字',

    // Main Call Screen
    'pageNumberPrefix': '第',
    'pageNumberSuffix': '頁',
    'firstPageWarning': '已經喺第一頁。',
    'lastPageWarning': '已經喺最後一頁。',
    'buttonFunctionMissing': '按鈕未有功能設定。',
    'buttonPhoneMissing': '按鈕沒有設定電話號碼。',
    'buttonCalling': '依家致電',
    'buttonCallFailed': '未能致電',
    'buttonSOSMissing': '未設置緊急SOS功能',
    'buttonSOSCalling': '緊急致電',

    // Notifications
    'callReadyTitle': '已啟動致電功能',
    'callReadyDescription': '按TapCall程式內的按鈕開始致電聯絡人。',
    'deviceConnectedTitle': '已連接',
    'deviceConnectedDescription': '你可以使用ESP32遙控器打電話。',
  };
  
  // Simplified Chinese (Mainland China)
  static final Map<String, String> _simplifiedChinese = {
    // Contact Editor
    'nameMissingReport': '请输入按钮名字。',
    'phoneMissingReport': '请输入联络人电话号码。',
    'functionTypeSubtitle': '功能类型',
    'photoChangeLabel': '更换照片',
    'deleteFunctionLabel': '刪除',
    'saveFunctionLabel': '储存',
    'messagingAppSubtitle': '通讯软体',
    'phoneNumberSubtitle': '电话号码',
    'phoneNumberGuide': '输入联络人电话号码',
    'nameChangeSubtitle': '按钮名字',
    'functionDeleteReport': '已删除功能！',
    'functionSaveReport': '功能已储存为：',
    'buttonIndexTitle': '按钮',
    'weatherDescription': '📢 播放现时日期和时间。',
    'timeDateDescription': '⛅ 播放现时天气预报。需要位置权限。',
    'nameChangeGuide': '输入按钮名字',

    // Settings Screen
    'contactDispName': '联系人',
    'timeDateDispName': '时间与日期',
    'weatherDispName': '天气',
    'addSOSLabel': '新增紧急联系人',
    'addContactLabel': '新增联系人',
    'addExtraLabel': '新增额外功能',
    'reorderFunctionHover': '更改功能次序',
    'uiLanguageTitle': '界面语言',
    'voLanguageTitle': '语音及字幕：',
    'enablePermLabel': '启用电话权限',
    'enableAccessLabel': '启用电话无障碍设置',
    'enableSetupDescription': '1. 启用电话与蓝牙权限\n2. 启用无障碍设置以自动拨号',
    'enableSetupTitle': 'TapCall 所需设置',
    'settingScreenTitle': '设置',
    'sosContactTitle': '紧急求助',
    'contactTitle': '联系人',
    'extraFunctionTitle': '额外功能',
    'contactPagePrefix': '页',
    'sosSetupTitle': '紧急联系人',
    'sosSetupDescription': '按下SOS按钮，致电紧急联络人。',
    'sosNameGuide': '联系人姓名',
    'sosPhoneGuide': '电话号码',
    'sosDeleteLabel': '删除',
    'sosCancelLabel': '取消',
    'sosSaveLabel': '储存',
    'emptySlotLabel': '未设联络人',
    'removeFunctionTitle': '移除槽位？',
    'removeFunctionDescription': '这将永久移除此按钮！',
    'removeCancelLabel': '取消',
    'removeConfirmLabel': '移除',
    'enableAccessReport': '在无障碍设置中启用「TapCall」',
    'sosMissingReport': '请输入姓名和电话号码',
    'requestPermReport': '已请求电话权限',
    
    // SOS Emergency
    'sos_emergency': '紧急求救',
    'sos_description': '按第 9 号按钮会直接拨打此联系人',

    // Reorder Screen
    'reorderScreenTitle': '更改功能次序',
    'reorderDiscardTitle': '放弃更改？',
    'reorderDiscardDescription': '您尚未储存功能次序。是否放弃更改？',
    'reorderCancelLabel': '取消',
    'reorderDiscardLabel': '放弃',
    'reorderSaveLabel': '储存',
    'reorderEmptyTitle': '尚未设定功能',
    'reorderEmptyDescription': '在设定页面中，新增联络人或功能',
    'reorderScreenDescription': '拖曳各功能更改次序。',

    // Contact App Names
    'whatsappDispName': 'Whatsapp',
    'wechatDispName': '微信',

    // Bluetooth Manager
    'bluetoothDeviceTitle': '管理蓝牙装置',
    'bluetoothDeviceScan': '搜寻蓝牙装置',
    'bluetoothDeviceScanning': '搜寻中...',
    'bluetoothDeviceEmpty': '未找到蓝牙装置\n\n请按「搜寻蓝牙装置」按钮，\n或檢查你的 ESP32 是否已啟動。',
    'bluetoothDeviceUnknown': '不明装置',
    'bluetoothDeviceSignal': '信号',
    'bluetoothDeviceClose': '返回',
    'bluetoothDeviceConnected': '已连接装置',
    'bluetoothDeviceName': '装置名字',

    // Main Call Screen
    'pageNumberPrefix': '第',
    'pageNumberSuffix': '頁',
    'firstPageWarning': '已经在第一页。',
    'lastPageWarning': '已经在最后一页。',
    'buttonFunctionMissing': '按钮没有功能设定。',
    'buttonPhoneMissing': '按钮没有设定电话号码。',
    'buttonCalling': '现在致电',
    'buttonCallFailed': '未能致电',
    'buttonSOSMissing': '没有设定紧急SOS功能',
    'buttonSOSCalling': '紧急SOS',

    // Notifications
    'callReadyTitle': '已启动致电功能',
    'callReadyDescription': '按TapCall程式内的按钮开始致电联络人。',
    'deviceConnectedTitle': '已连接',
    'deviceConnectedDescription': '你可以使用ESP32遥控器打电话。',
  };
  
  // TTS translations (voice announcements) - English
  static final Map<String, String> _ttsEnglish = {
    'no_function': 'No function set',
    'calling': 'Calling {name}',
    'call_failed': 'Call failed',
    'no_phone_number': 'No phone number set',
    'getting_weather': 'Getting weather information',
    'location_required': 'Location permission required for weather',
    'unable_location': 'Unable to get location',
    'weather_unavailable': 'Unable to get weather information',
    'no_reminder': 'No reminder message set',
    'emergency_calling': 'Emergency! Calling first contact',
    'no_contact_emergency': 'No contact available for emergency',
    'emergency_failed': 'Emergency action failed',
  };
  
  // TTS Cantonese translations
  static final Map<String, String> _ttsCantonese = {
    'no_function': '未設定功能',
    'calling': '打緊電話俾 {name}',
    'call_failed': '打電話失敗',
    'no_phone_number': '未設定電話號碼',
    'getting_weather': '查緊天氣資料',
    'location_required': '需要位置權限先可以查天氣',
    'unable_location': '搵唔到位置',
    'weather_unavailable': '搵唔到天氣資料',
    'no_reminder': '未設定提醒訊息',
    'emergency_calling': '緊急求救！打緊電話',
    'no_contact_emergency': '緊急聯絡人未設定',
    'emergency_failed': '緊急求救失敗',
  };
  
  // TTS Mandarin translations
  static final Map<String, String> _ttsMandarin = {
    'no_function': '未设定功能',
    'calling': '正在呼叫 {name}',
    'call_failed': '呼叫失败',
    'no_phone_number': '未设定电话号码',
    'getting_weather': '正在获取天气信息',
    'location_required': '需要位置权限才能查询天气',
    'unable_location': '无法获取位置',
    'weather_unavailable': '无法获取天气信息',
    'no_reminder': '未设定提醒消息',
    'emergency_calling': '紧急求救！正在呼叫',
    'no_contact_emergency': '紧急联系人未设定',
    'emergency_failed': '紧急求救失败',
  };
}
