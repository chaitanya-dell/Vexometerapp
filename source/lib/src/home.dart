
import 'package:flutter/material.dart';
import 'package:toast/toast.dart';
import 'package:vaxometer/src/globals.dart' as globals;
import 'package:vaxometer/src/models/vaccine-session.dart';
import 'package:vaxometer/src/shared/loader.dart';
import 'package:vaxometer/src/shared/services/geo-finder.dart';
import 'package:vaxometer/src/shared/services/vaxometer-service.dart';
import './shared/slot-tile.dart';
import 'models/vaccine-centre.dart';

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _deviceId;
  TextEditingController _searchController = new TextEditingController();
  VaxometerService _vaxometerService = new VaxometerService();
  Future<List<CentersViewModel>> _futureVaccineCentres;
  List<CentersViewModel> _vaccineCentres;
  List<CentersViewModel> _filteredVaccineCentres;
  String _pinCode = "";
  bool isPinEntered = true;
  var _vacCentrefilters = [true, true, true, true, true];
  //var _vacTypes = [ "Covishield", "Covaxin", "Sputnik V"];
  //var _vacTypesFilter = List.generate(3, (index) => true);
  Map<String, bool> _vaccineTypes ;//= {"Covishield": true, "Covaxin": true, "Sputnik V": true};
  Map<String, bool> ageFilter = {"age18": true, "age45" : true};

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {});
    });

    _futureVaccineCentres = _getVaccineCentre();
  }

  Future<List<CentersViewModel>> _getVaccineCentre() async {
    _pinCode = _searchController.text.isEmpty ? await GeoFinder.getPinCodeByMyLoction(): _searchController.text;
    var vaccCentres = await _vaxometerService.getCentresByPin(globals.onesignalUserId, _pinCode);
    var centersViewModel = vaccCentres.centersViewModel;
    centersViewModel.sort((a,b) => a.getInitialSlots().compareTo(b.getInitialSlots()));
    Map doseMap = {"Dose 1": true,"Dose 2": true };
    _vaccineTypes = new Map.fromIterable(vaccCentres.vaccineTypes,
    key: (item) => item,
      value: (item) => true
    );
    _vaccineTypes["Dose 1"] = true;
    _vaccineTypes["Dose 2"] = true;
    Loader.close(context);
    return centersViewModel;
  }

  bool _ageFilter(VaccineSession vs) {
    if (!_vacCentrefilters[0]) {
      ageFilter.update("age18", (value) => true);

      if(!_vacCentrefilters[1]){
        ageFilter.update("age45", (value) => true);
      } else
      ageFilter.update("age45", (value) => false);
      return vs.min_age_limit == 18;
    }
    if (!_vacCentrefilters[1]) {
      ageFilter.update("age45", (value) => true);
      if(!_vacCentrefilters[0]){
        ageFilter.update("age18", (value) => true);
      } else
        ageFilter.update("age18", (value) => false);
      return vs.min_age_limit == 45;

    }
    return true;

  }

  bool _feeTypeFilter(String feeType) {
    if (!_vacCentrefilters[2] && _vacCentrefilters[3])
      return feeType == 'Free';
    else if (_vacCentrefilters[2] && !_vacCentrefilters[3])
      return feeType == 'Paid';
    
    return true;
  }

  bool _vacTypeFilter(VaccineSession vs) {
    var vacTypes = [];
    _vaccineTypes.forEach((key, value) {
      if (value && (key!="Dose 1" && key!= "Dose 2"))
        vacTypes.add(key.toLowerCase());
     });
      
    return vacTypes.contains(vs.vaccine.toLowerCase());
  }
 void applyFilter() {
      _filteredVaccineCentres = _vaccineCentres.where((ele) => 
        (ele.sessions != null && ele.sessions.any((a) => _ageFilter(a))) 
        && _feeTypeFilter(ele.fee_type)
        && (ele.sessions != null && ele.sessions.any((a) => _vacTypeFilter(a)))

      ).toList();
      _filteredVaccineCentres.sort((a, b) => a.getSlots().compareTo(b.getSlots()));
  }

  ListView _vaccineCentreListView() {
    return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredVaccineCentres.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          return SlotTile(_filteredVaccineCentres[index],_vaccineTypes,ageFilter, callBack: (int centreId, bool isSubscribe) async {
            // return SlotTile(_filteredVaccineCentres[index], callBack: (int centreId, bool isSubscribe) async {
            Loader.show(context);
            await followCentre(centreId, isSubscribe);
            Loader.close(context);
            Toast.show(isSubscribe ? "Subscribed": "Un Subscribed", context, duration: Toast.LENGTH_SHORT, gravity:  Toast.BOTTOM);
            _pullRefresh().then((value) => {
              setState(() {})
            });
          });
        });
  }

  Future<void> _pullRefresh() async {
    _futureVaccineCentres = Future.value(_getVaccineCentre());
  }

  Future<void> followCentre(int centreId, bool isSubscribe) async {
    await _vaxometerService.followCentre(globals.onesignalUserId, centreId, isSubscribe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: buildBar(context),
        body: FutureBuilder<List<CentersViewModel>>(
              future: _futureVaccineCentres,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data.isNotEmpty) {
                  _vaccineCentres = snapshot.data;
                  _filteredVaccineCentres = _filteredVaccineCentres ?? _vaccineCentres;
                  return RefreshIndicator(
                      child: _vaccineCentreListView(),
                      onRefresh: () =>
                          _pullRefresh());
                } else if (snapshot.hasError) {
                  return Align(
                      alignment: Alignment.center,
                      child: Text("${snapshot.error}",
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                } else {
                  return Align(
                      alignment: Alignment.center,
                      child: Text("No records found " + _pinCode,
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)
                      ));
                }
              },
            ),
    );
  }
  
  void _showPopupMenu(Offset offset) async {
    double left = offset.dx;
    double top = offset.dy;
    await showMenu(
      context: context,
      color: Colors.blue[50],
      position: RelativeRect.fromLTRB(left, top, left+1, top+1),
      items: List.generate(_vaccineTypes.length, (index) => PopupMenuItem<bool>(
            child: StatefulBuilder(builder:
                  (BuildContext context, StateSetter setState) {
                    return CheckboxListTile(dense: true, selected: _vaccineTypes[_vaccineTypes.keys.elementAt(index)], contentPadding: EdgeInsets.all(0.0), 
            value: _vaccineTypes[_vaccineTypes.keys.elementAt(index)], onChanged: (bool value) {
              setState(() {
                _vaccineTypes[_vaccineTypes.keys.elementAt(index)] = value;
                applyFilter();
              });
            }, title: Text(_vaccineTypes.keys.elementAt(index)), 
            controlAffinity: ListTileControlAffinity.leading);}))),
      elevation: 0.0,
  );
}
  
  Widget buildBar(BuildContext context) {
    return new AppBar(
      leadingWidth: 35.0,
      flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blue[300]],
              ),
            ),
          ),
      // leading: IconButton(iconSize: 20.0, icon: Icon(Icons.list, color: Colors.white), onPressed: () {
          
      //   }),
      
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(35.0),
        child: Container(
          height: 35.0,
          padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
          color: Colors.white30,
          child: ToggleButtons(
              borderColor: Colors.white30,
              fillColor: Colors.white,
              borderRadius: BorderRadius.circular(6.0),
              selectedBorderColor: Colors.blue,
              color: Colors.blueGrey,
              children: <Widget>[
                Container(width: (MediaQuery.of(context).size.width - 9)/5, child:Text("18+", textAlign: TextAlign.center)),
                Container(width: (MediaQuery.of(context).size.width - 9)/5, child:Text("45+", textAlign: TextAlign.center)),
                Container(width: (MediaQuery.of(context).size.width - 9)/5, child:Text("Free", textAlign: TextAlign.center)),
                Container(width: (MediaQuery.of(context).size.width - 9)/5, child:Text("Paid", textAlign: TextAlign.center)),
                Container(width: (MediaQuery.of(context).size.width - 9)/5.1, child:GestureDetector(
                      onTapDown: (TapDownDetails details) {
                        _showPopupMenu(details.globalPosition);
                      },
                      child: Icon(Icons.filter_alt)))
              ],
              onPressed: (int index) {
                setState(() {
                  _vacCentrefilters[index] = !_vacCentrefilters[index];
                  applyFilter();
                });
              },
              isSelected: _vacCentrefilters
            )
        ),
      ),
      title: Container(
        height: 36.0,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey.withOpacity(0.5),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: TextField(
          controller: _searchController,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            fillColor: Colors.yellow,
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            isDense: true,
            suffixIcon: _searchController.text.isNotEmpty ? new IconButton(iconSize: 20.0, icon: new Icon(Icons.cancel), onPressed: () {
              _searchController.clear();
            }): null,
            hintStyle: TextStyle(color: Colors.grey),
            hintText: 'Search With Your Pincode',
          ),
        ),
      ),
      actions: <Widget>[
        Container(
          margin: EdgeInsets.only(top: 10.0, bottom: 10.0, right: 15.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontSize: 11.0),
                        padding: EdgeInsets.all(0.0),
                        primary: Colors.blue[700], // background
                        onPrimary: Colors.white, // foreground
                      ),
	        child: Icon(Icons.search, color: Colors.white),
	          onPressed: () async {
              if(_searchController.text.isNotEmpty) {
                Loader.show(context);
                await _pullRefresh();
                setState(() {
                  isPinEntered = true;
                });
              } else {
                setState(() {
                  isPinEntered = false;
                });
              }
            },
          ),
        )
      ]
    );
  }
}