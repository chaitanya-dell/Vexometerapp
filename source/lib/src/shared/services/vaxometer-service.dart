
import 'package:vaxometer/src/models/vaccine-centre.dart';
import 'package:vaxometer/src/shared/services/http-service.dart';

class VaxometerService {

  String _baseUrl = "https://vaxometerindia.azurewebsites.net/api/v1/";

  Future<List<VaccineCentre>> getCentresByPin(String deviceId, String pinCode) async {
    var response = await HttpService.get<dynamic>(_baseUrl + "Vaxometer/Centers/DeviceIds/$deviceId/Pincodes/$pinCode");
    var centres = response["centers"];
    var vaccCentres = List.from(centres).map((e) => VaccineCentre.fromJson(e)).toList();
    return vaccCentres;
  }

  Future<void> followCentre(String deviceId, int centreId, bool isSubscribe) async {
    await HttpService.post<bool>(_baseUrl + "Vaxometer/RegisterDevice/" + deviceId, {
      "deviceId": deviceId,
      "date": DateTime.now().toString(),
      "centerId": centreId,
      "isRegister": isSubscribe
    });
  }
}