class IndiaLocationData {
  static const Map<String, List<String>> _stateCityMap = {
  'Andaman and Nicobar Islands': ['Port Blair'],

  'Andhra Pradesh': [
    'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Tirupati',
    'Kurnool', 'Rajahmundry', 'Anantapur'
  ],

  'Arunachal Pradesh': [
    'Itanagar', 'Naharlagun', 'Tawang', 'Pasighat', 'Ziro'
  ],

  'Assam': [
    'Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Tezpur',
    'Nagaon', 'Tinsukia'
  ],

  'Bihar': [
    'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Darbhanga',
    'Purnia', 'Ara'
  ],

  'Chandigarh': ['Chandigarh'],

  'Chhattisgarh': [
    'Raipur', 'Bhilai', 'Bilaspur', 'Durg', 'Korba', 'Raigarh'
  ],

  'Dadra and Nagar Haveli and Daman and Diu': [
    'Silvassa', 'Daman', 'Diu'
  ],

  'Delhi': [
    'New Delhi', 'Central Delhi', 'North Delhi', 'South Delhi',
    'Dwarka', 'Rohini', 'Saket'
  ],

  'Goa': [
    'Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda'
  ],

  'Gujarat': [
    'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Gandhinagar',
    'Bhavnagar', 'Jamnagar', 'Junagadh'
  ],

  'Haryana': [
    'Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Karnal',
    'Hisar', 'Rohtak', 'Sonipat'
  ],

  'Himachal Pradesh': [
    'Shimla', 'Dharamshala', 'Mandi', 'Solan', 'Kullu', 'Manali'
  ],

  'Jammu and Kashmir': [
    'Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Pulwama'
  ],

  'Jharkhand': [
    'Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Hazaribagh'
  ],

  'Karnataka': [
    'Bengaluru', 'Mysuru', 'Mangaluru', 'Hubballi', 'Belagavi',
    'Davangere', 'Ballari'
  ],

  'Kerala': [
    'Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur',
    'Kannur', 'Alappuzha'
  ],

  'Ladakh': ['Leh', 'Kargil'],
  'Lakshadweep': ['Kavaratti'],

  'Madhya Pradesh': [
    'Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain',
    'Sagar', 'Rewa'
  ],

  'Maharashtra': [
  'Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Thane',
  'Navi Mumbai', 'Kalyan', 'Dombivli',
  'Vasai', 'Virar', 'Palghar', 'Boisar',
  'Mira Bhayandar', 
  'Aurangabad', 'Solapur', 'Kolhapur', 'Sangli',
  'Satara', 'Ratnagiri', 'Chiplun',
  'Jalgaon', 'Dhule', 'Nandurbar',
  'Ahmednagar', 'Latur', 'Osmanabad',
  'Beed', 'Parbhani', 'Nanded', 'Hingoli',
  'Akola', 'Amravati', 'Yavatmal',
  'Wardha', 'Bhandara', 'Gondia', 'Chandrapur', 'Gadchiroli'
],

  'Manipur': ['Imphal', 'Thoubal', 'Churachandpur'],

  'Meghalaya': ['Shillong', 'Tura', 'Jowai'],

  'Mizoram': ['Aizawl', 'Lunglei', 'Champhai'],

  'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung'],

  'Odisha': [
    'Bhubaneswar', 'Cuttack', 'Rourkela', 'Puri',
    'Berhampur', 'Sambalpur'
  ],

  'Puducherry': ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],

  'Punjab': [
    'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Mohali',
    'Bathinda'
  ],

  'Rajasthan': [
    'Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Ajmer',
    'Bikaner', 'Alwar'
  ],

  'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing'],

  'Tamil Nadu': [
    'Chennai', 'Coimbatore', 'Madurai', 'Salem', 'Tiruchirappalli',
    'Erode', 'Tirunelveli', 'Vellore'
  ],

  'Telangana': [
    'Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar',
    'Khammam'
  ],

  'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar'],

  'Uttar Pradesh': [
    'Lucknow', 'Kanpur', 'Noida', 'Varanasi', 'Prayagraj',
    'Ghaziabad', 'Agra', 'Meerut'
  ],

  'Uttarakhand': [
    'Dehradun', 'Haridwar', 'Haldwani', 'Roorkee', 'Nainital'
  ],

  'West Bengal': [
    'Kolkata', 'Howrah', 'Siliguri', 'Durgapur', 'Asansol',
    'Kharagpur'
  ],
};

  static const Map<String, Set<String>> _pincodeFirstDigitStateMap = {
    '1': {
      'Chandigarh',
      'Delhi',
      'Haryana',
      'Himachal Pradesh',
      'Jammu and Kashmir',
      'Ladakh',
      'Punjab',
    },
    '2': {
      'Uttar Pradesh',
      'Uttarakhand',
    },
    '3': {
      'Dadra and Nagar Haveli and Daman and Diu',
      'Gujarat',
      'Rajasthan',
    },
    '4': {
      'Chhattisgarh',
      'Goa',
      'Madhya Pradesh',
      'Maharashtra',
    },
    '5': {
      'Andhra Pradesh',
      'Karnataka',
      'Telangana',
    },
    '6': {
      'Kerala',
      'Lakshadweep',
      'Puducherry',
      'Tamil Nadu',
    },
    '7': {
      'Andaman and Nicobar Islands',
      'Arunachal Pradesh',
      'Assam',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Odisha',
      'Sikkim',
      'Tripura',
      'West Bengal',
    },
    '8': {
      'Bihar',
      'Jharkhand',
    },
  };

  static List<String> get states {
    final values = _stateCityMap.keys.toList()..sort();
    return values;
  }

  static List<String> citiesForState(String? state) {
    if (state == null || state.trim().isEmpty) {
      return const [];
    }

    final cities = _stateCityMap[state.trim()];
    if (cities == null) {
      return const [];
    }

    final values = [...cities]..sort();
    return values;
  }

  static bool stateExists(String value) {
    return _stateCityMap.containsKey(value.trim());
  }

  static bool cityBelongsToState({
    required String state,
    required String city,
  }) {
    final stateKey = state.trim();
    final cityValue = city.trim().toLowerCase();
    if (stateKey.isEmpty || cityValue.isEmpty) {
      return false;
    }

    final cities = _stateCityMap[stateKey];
    if (cities == null) {
      return false;
    }

    return cities.any((item) => item.toLowerCase() == cityValue);
  }

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValidIndianPhone(String value) {
    final digits = digitsOnly(value);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
  }

  static bool isValidIndianPincode(String value) {
    return RegExp(r'^[1-9]\d{5}$').hasMatch(value.trim());
  }

  static bool isPincodeCompatibleWithState({
    required String state,
    required String pincode,
  }) {
    if (!isValidIndianPincode(pincode)) {
      return false;
    }

    final normalizedState = state.trim();
    if (normalizedState.isEmpty) {
      return true;
    }

    final allowedStates = _pincodeFirstDigitStateMap[pincode.trim()[0]];
    if (allowedStates == null || allowedStates.isEmpty) {
      return true;
    }

    return allowedStates.contains(normalizedState);
  }
}
