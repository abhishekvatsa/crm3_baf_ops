// ─────────────────────────────────────────────────────────────
// DomainRegistry — BAF CRM-III, SAIL Bokaro
// Source: RAD-CON Safety and Operations Manual
//         Ref. 7-1-13-0028-41-1011 (Rev 0, Nov 2012)
// ─────────────────────────────────────────────────────────────

class DomainRegistry {
  static const Map<String, dynamic> data = {
    "Base": {
      "Structure": {
        "components": [
          {"name": "Base Frame"},
          {"name": "Insulated Sheath"},
          {"name": "Charge Plate"},
          {"name": "Convector Plate"},
          {"name": "Terminal Box"},
          {"name": "Guide Pins"},
          {"name": "Base Seal"}
        ]
      },
      "Circulation System": {
        "components": [
          {"name": "Fan Wheel"},
          {"name": "Fan Motor"},
          {"name": "Diffuser"}
        ]
      },
      "Clamping System": {
        "components": [
          {"name": "Hydraulic Clamps"},
          {"name": "Pressure Gauge"},
          {"name": "Pressure Switch", "tags": ["PSL13", "PSL14"]},
          {"name": "Manual Valves"}
        ]
      },
      "Thermal Monitoring": {
        "components": [
          {"name": "Gas Stream Thermocouple", "tags": ["TE02A", "TE02B"]},
          {"name": "Base Thermocouple", "tags": ["TE03"]},
          {"name": "Cooling Water Exit Thermocouple", "tags": ["TE05"]}
        ]
      },
      "Proximity Switches": {
        "components": [
          {"name": "Furnace / Forced Cooler Proximity Switch", "tags": ["YS00"]},
          {"name": "Inner Cover Proximity Switch", "tags": ["YS01"]},
          {"name": "Nitrogen Manual Valve Proximity Switch", "tags": ["YS25"]},
          {"name": "Fuel Gas Safety Valve Proximity Switch", "tags": ["YS50"]}
        ]
      },
      "Water Box": {
        "components": [
          {"name": "Water Box"},
          {"name": "Cooling Water Flow Indicator / Switch", "tags": ["FISL61"]}
        ]
      }
    },
    "Inner Cover": {
      "Structure": {
        "components": [
          {"name": "Head"},
          {"name": "Barrel"},
          {"name": "Lifting Ring"},
          {"name": "Guide Arm"}
        ]
      },
      "Drain System": {
        "components": [
          {"name": "Drain Spout"},
          {"name": "Plunger"},
          {"name": "Spring"},
          {"name": "Gasket"}
        ]
      },
      "Cooling System": {
        "components": [
          {"name": "Cooling Jacket"},
          {"name": "Water Connections"},
          {"name": "Water Catch Ring"}
        ]
      },
      "Safety": {
        "components": [
          {"name": "Fusible Plug (Temperature Limit Fuse)"}
        ]
      },
      "Sealing": {
        "components": [
          {"name": "Seal Mating Surface"}
        ]
      }
    },
    "Furnace": {
      "Structure": {
        "components": [
          {"name": "Furnace Casing"},
          {"name": "Guide Arm"},
          {"name": "Lifting Eye"}
        ]
      },
      "Combustion System": {
        "components": [
          {"name": "Burner"},
          {"name": "Combustion Air Blower"},
          {"name": "Air Manifold"},
          {"name": "Recuperator"}
        ]
      },
      "Air System": {
        "components": [
          {"name": "Air Control Valve", "tags": ["ZT31"]},
          {"name": "Air Flow Transmitter", "tags": ["FIT31"]},
          {"name": "Air Flow Switch", "tags": ["FSL33"]},
          {"name": "Air Pressure Switch", "tags": ["PSL30"]},
          {"name": "Air Thermocouple", "tags": ["TE31"]}
        ]
      },
      "Fuel System": {
        "components": [
          {"name": "Fuel Control Valve", "tags": ["ZT54"]},
          {"name": "Fuel Flow Transmitter", "tags": ["FIT54"]},
          {"name": "Fuel Pressure Switch High", "tags": ["PSH51"]},
          {"name": "Fuel Pressure Switch Low", "tags": ["PSL52"]},
          {"name": "Safety Shutoff Valve", "tags": ["YIV53"]},
          {"name": "Mixed Fuel Thermocouple", "tags": ["TE51"]}
        ]
      },
      "Monitoring": {
        "components": [
          {"name": "High Limit Thermocouple", "tags": ["TE00"]},
          {"name": "Waste Gas Thermocouple", "tags": ["TE01"]}
        ]
      },
      "Exhaust Interface": {
        "components": [
          {"name": "Waste Gas Collection Hood"},
          {"name": "Downcomer"},
          {"name": "Damper"}
        ]
      },
      "Control System": {
        "components": [
          {"name": "Control Panel"},
          {"name": "Power Panel"},
          {"name": "Control Plug"},
          {"name": "Analog Plug"},
          {"name": "Power Plug"}
        ]
      }
    },
    "Forced Cooler": {
      "Air Cooling": {
        "components": [
          {"name": "Blower Motor"},
          {"name": "Impeller"},
          {"name": "Air Inlet"},
          {"name": "Air Exhaust"}
        ]
      },
      "Water Cooling": {
        "components": [
          {"name": "Spray Water System"},
          {"name": "Butterfly Water Valve", "tags": ["YIV60"]},
          {"name": "Water Flow Indicator / Switch", "tags": ["FISL61"]},
          {"name": "Flex Hose with Quick Connect"}
        ]
      },
      "Structure": {
        "components": [
          {"name": "Cooler Body"},
          {"name": "Lifting Ring"}
        ]
      }
    },
    "Valve Stand": {
      "Leak Test System": {
        "components": [
          {"name": "Leak Test Valve", "tags": ["YIV47"]},
          {"name": "Pressure Regulator", "tags": ["PCV47"]},
          {"name": "Pressure Switch", "tags": ["PSL47"]}
        ]
      },
      "Atmosphere Control": {
        "components": [
          {"name": "Inlet Valve", "tags": ["YIV25"]},
          {"name": "Outlet Valve", "tags": ["YIV78"]}
        ]
      },
      "Atmosphere Exhaust": {
        "components": [
          {"name": "Back Pressure Valve", "tags": ["PCV77"]},
          {"name": "Inner Cover Pressure Transmitter", "tags": ["PT74"]},
          {"name": "Pressure Relief Regulator", "tags": ["PCV70"]},
          {"name": "Inner Cover High Pressure Switch", "tags": ["PSH71"]},
          {"name": "Inner Cover Low Pressure Switch", "tags": ["PSL76"]},
          {"name": "Inner Cover Low/Low Pressure Switch", "tags": ["PSL75"]}
        ]
      },
      "Nitrogen Purge": {
        "components": [
          {"name": "Solenoid Valve", "tags": ["YV26", "YV27"]},
          {"name": "Nitrogen Flow Transmitter", "tags": ["FIT25"]},
          {"name": "Nitrogen Flow Switch", "tags": ["FSL25", "FSL26"]},
          {"name": "Motor Purge Flow Meter", "tags": ["FIV27"]}
        ]
      },
      "Hydrogen Control": {
        "components": [
          {"name": "Blocking Valve", "tags": ["YV45"]},
          {"name": "Flow Control Valve", "tags": ["FOV46A", "FOV46B"]},
          {"name": "Hydrogen Flow Meter", "tags": ["FIT45"]}
        ]
      }
    },
    "Auxiliary Base Hardware": {
      "Mixed Fuel Piping": {
        "components": [
          {"name": "Fuel Gas Safety Shut-Off Valve", "tags": ["YIV50"]},
          {"name": "Manual Gate Valve"},
          {"name": "Fuel Gas Connector"}
        ]
      },
      "Atmosphere Outlet Piping": {
        "components": [
          {"name": "Manual Valve"},
          {"name": "Cooling Jacket"},
          {"name": "Condensate Collector"},
          {"name": "Condensation Drain Valve", "tags": ["YIV72"]},
          {"name": "Atmosphere Exhaust Valve", "tags": ["YIV73"]},
          {"name": "Sample Line"},
          {"name": "Sample Filter"}
        ]
      },
      "Water Piping": {
        "components": [
          {"name": "Butterfly Water Valve", "tags": ["YIV60"]},
          {"name": "Water Flow Indicator / Switch", "tags": ["FISL61"]},
          {"name": "Manual Water Valve"},
          {"name": "Flex Hose with Quick Connect"}
        ]
      },
      "Motor Purge": {
        "components": [
          {"name": "Motor Purge Flow Meter", "tags": ["FIV27"]}
        ]
      }
    },
    "Pressure Reducing Station": {
      "Nitrogen Side": {
        "components": [
          {"name": "Pressure Reducing Regulator"},
          {"name": "Pressure Gauge"},
          {"name": "Nitrogen High Pressure Switch", "tags": ["PSH22"]},
          {"name": "Nitrogen Low Pressure Switch", "tags": ["PSL21"]},
          {"name": "Manual Isolation Valve"}
        ]
      },
      "Hydrogen Side": {
        "components": [
          {"name": "Pressure Reducing Regulator"},
          {"name": "Pressure Gauge"},
          {"name": "Hydrogen High Pressure Switch", "tags": ["PSH42"]},
          {"name": "Hydrogen Low Pressure Switch", "tags": ["PSL41"]},
          {"name": "Manual Isolation Valve"}
        ]
      }
    },
    "Hydraulic Power Pack": {
      "Oil System": {
        "components": [
          {"name": "Hydraulic Pump Motor"},
          {"name": "Nitrogen Backup Pump"},
          {"name": "Oil Level Switch LO", "tags": ["LSL06"]},
          {"name": "Oil Level Switch LO/LO", "tags": ["LSL04"]},
          {"name": "Oil Temperature Switch HI", "tags": ["TSH01"]},
          {"name": "Oil Temperature Switch HI/HI", "tags": ["TSH02"]},
          {"name": "Hydraulic Pressure Switch", "tags": ["PSL10"]},
          {"name": "Oil Reservoir"},
          {"name": "Oil Filter"}
        ]
      }
    },
    "Exhaust System": {
      "components": [
        {"name": "Flue Tunnel"},
        {"name": "Waste Gas Path"},
        {"name": "Damper"},
        {"name": "Downcomer"},
        {"name": "Chimney"},
        {"name": "Metal Mesh Guard"}
      ]
    },
    "Gas Systems": {
      "Nitrogen Header": {
        "components": [
          {"name": "Nitrogen Flow Transmitter", "tags": ["FIT12"]},
          {"name": "Nitrogen Pressure Transmitter", "tags": ["PIT13"]},
          {"name": "Nitrogen Pressure Relief Valve", "tags": ["PSV11"]},
          {"name": "Pneumatic Supply Pressure Switch", "tags": ["PSL15"]}
        ]
      },
      "Hydrogen Header": {
        "components": [
          {"name": "Hydrogen Flow Transmitter", "tags": ["FIT32"]},
          {"name": "Hydrogen Pressure Transmitter", "tags": ["PIT33"]},
          {"name": "Hydrogen Pressure Relief Valve", "tags": ["PSV31"]}
        ]
      },
      "Mixed Fuel Header": {
        "components": [
          {"name": "Mixed Fuel Flow Transmitter", "tags": ["FIT52"]},
          {"name": "Mixed Fuel Pressure Transmitter", "tags": ["PIT53"]},
          {"name": "Mixed Fuel High Pressure Switch", "tags": ["PSH55"]},
          {"name": "Mixed Fuel Low Pressure Switch", "tags": ["PSL54"]}
        ]
      },
      "Cooling Water Header": {
        "components": [
          {"name": "Supply Water Flow Transmitter", "tags": ["FIT62"]},
          {"name": "Supply Water Pressure Transmitter", "tags": ["PIT63"]}
        ]
      },
      "Hydrogen System": {
        "components": [
          {"name": "Blocking Valve", "tags": ["YV45"]},
          {"name": "Flow Control Valve", "tags": ["FOV46A", "FOV46B"]},
          {"name": "Flow Transmitter", "tags": ["FIT45"]}
        ]
      },
      "Nitrogen System": {
        "components": [
          {"name": "Flow Transmitter", "tags": ["FIT25"]},
          {"name": "Flow Switch", "tags": ["FSL25", "FSL26"]},
          {"name": "Solenoid Valve", "tags": ["YV26", "YV27"]}
        ]
      }
    },
    "Cooling Systems": {
      "components": [
        {"name": "Forced Cooler"},
        {"name": "Air Cooling System"},
        {"name": "Chilled Water System"},
        {"name": "Spray Water System"}
      ]
    }
  };
}
