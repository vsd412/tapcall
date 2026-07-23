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
    // Settings Screen
    'settings': 'Settings',
    'required_setup': 'Required Setup',
    'required_setup_desc': '1. Enable Phone & Bluetooth permissions\n2. Enable Accessibility service for auto-calling',
    'enable_permissions': 'Enable Permissions',
    'enable_accessibility': 'Enable Accessibility',
    'enable_accessibility_msg': 'Enable "TapCall" in Accessibility',
    'voice_subtitle': 'Voice & Subtitle',
    'ui_language': 'UI Language',
    'contacts': 'Contacts',
    'extra_functions': 'Extra Functions',
    'add_more_contacts': 'Add More Contacts (1 more)',
    'add_more_extra_functions': 'Add More Extra Functions (1 more)',
    'max_extra_functions': 'Maximum 3 extra functions reached',
    'remove_slot': 'Remove Slot?',
    'remove_slot_confirm': 'This will permanently remove this slot and its configuration.',
    'cancel': 'Cancel',
    'remove': 'Remove',
    'empty_slot': 'Empty Slot',
    'permissions_requested': 'Permissions requested',
    'error': 'Error: {error}',
    'page': 'Page {number}',
    
    // Contact Editor
    'edit_contact': 'Edit Slot {number}',
    'contact_name': 'Contact Name',
    'phone_number': 'Phone Number',
    'app_type': 'App Type',
    'pick_photo': 'Pick Photo',
    'function_type': 'Function Type',
    'reminder_time': 'Reminder Time (HH:mm)',
    'reminder_days': 'Reminder Days',
    'reminder_message': 'Reminder Message',
    'emergency_message': 'Emergency Message',
    'save': 'Save',
    'delete': 'Delete',
    'saved': 'Saved!',
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
    
    // Main Screen
    'ble_connected': 'BLE Connected',
    'ble_disconnected': 'BLE Not Connected',
    'accessibility_required': 'Accessibility Required',
    'location_required_weather': 'Location Required',
    'page_indicator': '{current}/{total}',
    'hold_settings': 'Hold for Settings',
    'no_contacts_yet': 'No Contacts Yet',
    'add_contacts_message': 'Add contacts in settings to start making calls',
    'open_settings': 'Open Settings',
    
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
    // Settings Screen
    'settings': '設定',
    'required_setup': '必需設定',
    'required_setup_desc': '1. 啟用電話及藍牙權限\n2. 啟用無障礙服務以自動撥號',
    'enable_permissions': '啟用權限',
    'enable_accessibility': '啟用無障礙服務',
    'enable_accessibility_msg': '在無障礙設定中啟用「TapCall」',
    'voice_subtitle': '語音及字幕',
    'ui_language': '介面語言',
    'contacts': '聯絡人',
    'extra_functions': '額外功能',
    'add_more_contacts': '新增更多聯絡人（再加 1 個）',
    'add_more_extra_functions': '新增更多額外功能（再加 1 個）',
    'max_extra_functions': '已達最多 3 個額外功能',
    'remove_slot': '移除此格？',
    'remove_slot_confirm': '這將永久移除此格及其設定。',
    'cancel': '取消',
    'remove': '移除',
    'empty_slot': '空白格',
    'permissions_requested': '已要求權限',
    'error': '錯誤：{error}',
    'page': '第 {number} 頁',
    
    // Contact Editor
    'edit_contact': '編輯第 {number} 格',
    'contact_name': '聯絡人名稱',
    'phone_number': '電話號碼',
    'app_type': '應用程式',
    'pick_photo': '選擇照片',
    'function_type': '功能類型',
    'reminder_time': '提醒時間（HH:mm）',
    'reminder_days': '提醒日子',
    'reminder_message': '提醒訊息',
    'emergency_message': '緊急訊息',
    'save': '儲存',
    'delete': '刪除',
    'saved': '已儲存！',
    'monday': '一',
    'tuesday': '二',
    'wednesday': '三',
    'thursday': '四',
    'friday': '五',
    'saturday': '六',
    'sunday': '日',
    
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
    // Settings Screen
    'settings': '设置',
    'required_setup': '必需设置',
    'required_setup_desc': '1. 启用电话及蓝牙权限\n2. 启用无障碍服务以自动拨号',
    'enable_permissions': '启用权限',
    'enable_accessibility': '启用无障碍服务',
    'enable_accessibility_msg': '在无障碍设置中启用「TapCall」',
    'voice_subtitle': '语音及字幕',
    'ui_language': '界面语言',
    'contacts': '联系人',
    'extra_functions': '额外功能',
    'add_more_contacts': '添加更多联系人（再加 1 个）',
    'add_more_extra_functions': '添加更多额外功能（再加 1 个）',
    'max_extra_functions': '已达最多 3 个额外功能',
    'remove_slot': '移除此格？',
    'remove_slot_confirm': '这将永久移除此格及其设置。',
    'cancel': '取消',
    'remove': '移除',
    'empty_slot': '空白格',
    'permissions_requested': '已请求权限',
    'error': '错误：{error}',
    'page': '第 {number} 页',
    
    // Contact Editor
    'edit_contact': '编辑第 {number} 格',
    'contact_name': '联系人名称',
    'phone_number': '电话号码',
    'app_type': '应用程序',
    'pick_photo': '选择照片',
    'function_type': '功能类型',
    'reminder_time': '提醒时间（HH:mm）',
    'reminder_days': '提醒日期',
    'reminder_message': '提醒消息',
    'emergency_message': '紧急消息',
    'save': '保存',
    'delete': '删除',
    'saved': '已保存！',
    'monday': '一',
    'tuesday': '二',
    'wednesday': '三',
    'thursday': '四',
    'friday': '五',
    'saturday': '六',
    'sunday': '日',
    
    // Main Screen
    'ble_connected': '蓝牙已连接',
    'ble_disconnected': '蓝牙未连接',
    'accessibility_required': '需要无障碍服务',
    'location_required_weather': '需要位置权限',
    'page_indicator': '{current}/{total}',
    'hold_settings': '长按进入设置',
    'no_contacts_yet': '未有联系人',
    'add_contacts_message': '在设置中添加联系人以开始通话',
    'open_settings': '打开设置',
    
    // SOS Emergency
    'sos_emergency': '紧急求救',
    'sos_description': '按第 9 号按钮会直接拨打此联系人',

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
