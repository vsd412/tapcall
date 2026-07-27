/*
TapCall — Contact model

Represents one assigned slot with user-facing display name, region code (e.g. "+852"), local number, and preferred launch app (e.g. "whatsapp" or "phone").
- Slot is 1-based and indicates the ordered position in the UI.
- Immutable data class with `copyWith()` for safe updates.
- Provides `fullNumber` convenience getter.
- Includes JSON serialization (`toJson`) and deserialization (`fromJson`) for persistence.
*/

class Contact {
	final int slot; // Fixed position (1-based) that this contact occupies
	final String name;
	final String regionCode; // e.g. +852
	final String number; // local number without region code
	final String app; // e.g. whatsapp or phone

	const Contact({
		required this.slot,
		required this.name,
		required this.regionCode,
		required this.number,
		required this.app,
	});

	String get fullNumber => '$regionCode$number';

	Contact copyWith({
		int? slot,
		String? name,
		String? regionCode,
		String? number,
		String? app,
	}) => Contact(
				slot: slot ?? this.slot,
				name: name ?? this.name,
				regionCode: regionCode ?? this.regionCode,
				number: number ?? this.number,
				app: app ?? this.app,
			);

	Map<String, dynamic> toJson() => {
				'slot': slot,
				'name': name,
				'regionCode': regionCode,
				'number': number,
				'app': app,
			};

	factory Contact.fromJson(Map<String, dynamic> json) => Contact(
				slot: json['slot'] as int? ?? 0,
				name: json['name'] as String? ?? '',
				regionCode: json['regionCode'] as String? ?? '',
				number: json['number'] as String? ?? '',
				app: json['app'] as String? ?? 'whatsapp',
			);
}
