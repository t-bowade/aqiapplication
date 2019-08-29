
/// CityModel.dart
import 'dart:convert';

City CityFromJson(String str) {
    final jsonData = json.decode(str);
    return City.fromJson(jsonData);
}

String CityToJson(City data) {
    final dyn = data.toJson();
    return json.encode(dyn);
}

class City {
    String id;
    double lat;
    double long;
    String name;

    City({
        this.id,
        this.lat,
        this.long,
        this.name,
    });

    factory City.fromJson(Map<String, dynamic> json) => new City(
        id: json["city"] + json["state"] ,
        lat: json["first_name"],
        long: json["long"],
        name: json["city"],
    );


    Map<String, dynamic> toJson() => {
        "id": id,
        "lat": lat,
        "long": long,
        "name": name,
    };
}
