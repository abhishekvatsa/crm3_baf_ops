// FILE: lib/features/planned_maintenance/data/baf_module_catalogue_seed.dart

import 'dart:convert';

import '../../maintenance/data/maintenance_model.dart';
import 'job_module_model.dart';

/// Manual-derived seed catalogue for BAF process modules.
///
/// This file is intentionally not a full admin-governed template system yet.
/// It mirrors the future governance shape so that these seed records can later
/// be migrated into TemplatePackage / TemplateVersion / TemplateModule without
/// changing the JobModuleInstance runtime model.
class BafModuleCatalogueSeed {
  static const String seedVersion = 'manualCatalogueV0_3';
  static const String sourceLabel =
      'Emergency/manual seed catalogue v0.3';

  static const List<BafModuleSeed> modules = <BafModuleSeed>[
    // ─────────────────────────────────────────────────────────
    // BASE
    // ─────────────────────────────────────────────────────────
    BafModuleSeed(
      moduleCode: 'B-01',
      moduleTitle: 'Base Seal / O-Ring / Leak Integrity',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Seal integrity and leak path',
      componentGroup: 'Base seal and leak-test interface',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-11505', 'SP-10001', 'SP-11500'],
      operationalStatePreconditions: [
        'Base safe for inspection',
        'Controlled pressurization for leak test',
      ],
      safetyConfirmations: ['PPE', 'Pressure-test caution', 'Gas leak awareness'],
      fields: [
        BafModuleFieldSeed('sealCondition', 'Seal condition', 'enum', options: ['OK', 'Cracked', 'Hard', 'Charred', 'Replaced']),
        BafModuleFieldSeed('sealAreaClean', 'Seal area cleaned', 'boolean'),
        BafModuleFieldSeed('troughCondition', 'Trough condition', 'text'),
        BafModuleFieldSeed('leakTestResult', 'Leak-test result', 'enum', options: ['Pass', 'Fail', 'Not done']),
        BafModuleFieldSeed('leakPressureReading', 'Leak pressure reading', 'numericWithUnit', unit: 'in. W.C.'),
        BafModuleFieldSeed('suspectedLeakSource', 'Suspected leak source', 'multiSelect'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-01-01', 'Inspect seal for cracks, hard spots and charred areas.'),
        BafStandardJobItemSeed('B-01-02', 'Clean seal area and trough.'),
        BafStandardJobItemSeed('B-01-03', 'Record leak-test result and suspected leak path.'),
      ],
      addAsYouGoTriggers: ['Leak test fails', 'Seal damage seen', 'Pressure drop unexplained'],
      closedDossierOutput: 'Seal condition, cleaning status, leak-test result, suspected source and repair status.',
    ),
    BafModuleSeed(
      moduleCode: 'B-02',
      moduleTitle: 'Base Hydraulic Clamping System',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Inner-cover hold-down and clamp safety',
      componentGroup: 'Hydraulic clamps / PSL13 / PSL14',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.lotoRequired,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['HDC05758C000'],
      operationalStatePreconditions: ['Base IDLE for clamp troubleshooting', 'Unsafe cycle state ruled out'],
      safetyConfirmations: ['LOTO where hands enter clamp zone', 'Hydraulic pressure awareness'],
      fields: [
        BafModuleFieldSeed('clampAction', 'Clamp action', 'enum', options: ['Normal', 'Slow', 'Failed', 'Partial']),
        BafModuleFieldSeed('clampGroupAffected', 'Clamp group affected', 'multiSelect', options: ['A', 'B', 'Other']),
        BafModuleFieldSeed('hydraulicPressureA', 'Hydraulic pressure A', 'numericWithUnit', unit: 'bar'),
        BafModuleFieldSeed('hydraulicPressureB', 'Hydraulic pressure B', 'numericWithUnit', unit: 'bar'),
        BafModuleFieldSeed('PSL13Status', 'PSL13 status', 'enum'),
        BafModuleFieldSeed('PSL14Status', 'PSL14 status', 'enum'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-02-01', 'Observe clamped and unclamped action.'),
        BafStandardJobItemSeed('B-02-02', 'Check hydraulic pump fluid and tubing/cylinder leakage.'),
        BafStandardJobItemSeed('B-02-03', 'Record pressure switch status and PLC/alarm context.'),
      ],
      addAsYouGoTriggers: ['Clamps fail', 'Partial clamp actuation', 'Hydraulic alarm', 'Sluggish clamp movement'],
      closedDossierOutput: 'Clamp movement, pressure status, adjustment/leak findings and unresolved clamping risk.',
    ),
    BafModuleSeed(
      moduleCode: 'B-03A',
      moduleTitle: 'Base Fan Wheel Mechanical',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Atmosphere circulation - mechanical fan path',
      componentGroup: 'Base fan wheel',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.lotoRequired,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-16001'],
      operationalStatePreconditions: ['Base fan disconnected', 'Fan locked out before hand rotation'],
      safetyConfirmations: ['LOTO confirmed', 'Rotating equipment hazard controlled'],
      fields: [
        BafModuleFieldSeed('fanInspectionResult', 'Fan inspection result', 'enum'),
        BafModuleFieldSeed('fanTurnsFreely', 'Fan turns freely by hand', 'boolean'),
        BafModuleFieldSeed('rubbingBinding', 'Rubbing / binding observed', 'boolean'),
        BafModuleFieldSeed('crackFound', 'Crack or distortion found', 'boolean'),
        BafModuleFieldSeed('fanBalanced', 'Fan balanced / removed for balance', 'boolean'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-03A-01', 'Inspect fan wheel condition and free rotation.'),
        BafStandardJobItemSeed('B-03A-02', 'Record rubbing, binding, crack, distortion or balance requirement.'),
      ],
      addAsYouGoTriggers: ['Fan will not start', 'Unusual vibration or noise', 'Circulation issue', 'Leak test implicates fan/motor flange'],
      closedDossierOutput: 'Fan integrity, clearance/rubbing status, balance/removal status and post-run observation.',
    ),
    BafModuleSeed(
      moduleCode: 'B-03B',
      moduleTitle: 'Base Fan Motor / VFD / Aux Blower',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Motor drive and electrical availability',
      componentGroup: 'Base fan motor drive and permissive chain',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: ['SP-17001'],
      operationalStatePreconditions: ['Motor/VFD/MCC safe to inspect', 'E-stop/disconnect state verified'],
      safetyConfirmations: ['Electrical isolation', 'LOTO', 'Rotating equipment hazard controlled'],
      fields: [
        BafModuleFieldSeed('VFDStatus', 'VFD status', 'enum'),
        BafModuleFieldSeed('motorStarterStatus', 'Motor starter status', 'enum'),
        BafModuleFieldSeed('overloadTripped', 'Overload tripped', 'boolean'),
        BafModuleFieldSeed('auxBlowerStatus', 'Auxiliary blower status', 'enum'),
        BafModuleFieldSeed('VT07Reading', 'VT07 reading', 'numericWithUnit'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-03B-01', 'Check disconnects, VFD/starter, overloads and E-stop.'),
        BafStandardJobItemSeed('B-03B-02', 'Record auxiliary blower and PLC alarm/permissive cause.'),
      ],
      addAsYouGoTriggers: ['Base fan will not start', 'High temperature alarm', 'Blower failure', 'Vibration trip', 'Electrical trip'],
      closedDossierOutput: 'Motor/VFD health, trip cause, auxiliary blower status and alarm findings.',
    ),
    BafModuleSeed(
      moduleCode: 'B-04',
      moduleTitle: 'Base Diffuser / Charge Plate / Convector Plate',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Charge support and atmosphere flow distribution',
      componentGroup: 'Diffuser / charge plate / convector plate',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.shutdownWork,
      procedureRefs: ['SP-12002', 'SP-12004', 'SP-13002', 'SP-13003', 'SP-13501', 'SP-13502', 'SP-13503'],
      operationalStatePreconditions: ['Base safe for component removal', 'Charge/plate handling condition confirmed'],
      safetyConfirmations: ['LOTO above fan', 'Hot-equipment PPE', 'Lifting/handling safety'],
      fields: [
        BafModuleFieldSeed('diffuserAlignment', 'Diffuser alignment', 'enum'),
        BafModuleFieldSeed('chargePlateCondition', 'Charge plate condition', 'enum'),
        BafModuleFieldSeed('convectorPlateCondition', 'Convector plate condition', 'enum'),
        BafModuleFieldSeed('crackLength', 'Crack length', 'numericWithUnit', unit: 'mm'),
        BafModuleFieldSeed('repairRequired', 'Repair required', 'boolean'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-04-01', 'Check diffuser alignment and deterioration.'),
        BafStandardJobItemSeed('B-04-02', 'Inspect charge/convector plates for cracks, droop and distortion.'),
      ],
      addAsYouGoTriggers: ['Visible crack/droop', 'Flow/circulation concern', 'Clearance risk', 'Abnormal coil contact'],
      closedDossierOutput: 'Structural condition, clearance risk, repair/refinishing and removal/reinstall notes.',
    ),
    BafModuleSeed(
      moduleCode: 'B-05',
      moduleTitle: 'Base Atmosphere Piping / Back Pressure / Condensate Drain',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Atmosphere inlet/outlet, exhaust and condensate path',
      componentGroup: 'Base atmosphere path and condensate drain',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: ['SP-10001'],
      operationalStatePreconditions: ['Base in safe test/maintenance state', 'Exhaust/drain access permitted'],
      safetyConfirmations: ['Gas leak awareness', 'Pressure-test caution', 'PPE'],
      fields: [
        BafModuleFieldSeed('backPressureValveCleaned', 'Back pressure valve cleaned', 'boolean'),
        BafModuleFieldSeed('pipingCondition', 'Piping condition', 'enum'),
        BafModuleFieldSeed('drainsRodThrough', 'Condensate drains rodded through', 'boolean'),
        BafModuleFieldSeed('PT74LineChecked', 'PT74 line checked', 'boolean'),
        BafModuleFieldSeed('blockageFound', 'Blockage found', 'boolean'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-05-01', 'Open/clean back pressure valve and inspect piping/flanges.'),
        BafStandardJobItemSeed('B-05-02', 'Rod condensate drains and blow down exhaust lines.'),
      ],
      addAsYouGoTriggers: ['Leak test fails', 'Pressure control abnormal', 'Condensate accumulation', 'No nitrogen flow'],
      closedDossierOutput: 'Cleanliness, leak/pressure root cause, valve/transmitter concerns and atmosphere-path readiness.',
    ),
    BafModuleSeed(
      moduleCode: 'B-06',
      moduleTitle: 'Base Cooling Water Jacket / Water Connections',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Seal cooling and water safety',
      componentGroup: 'Base water jacket / TE05 / FISL61',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-11500'],
      operationalStatePreconditions: ['Cooling path isolated as procedure requires', 'Pressure-test setup controlled'],
      safetyConfirmations: ['Water pressure testing safety', 'Hot water/steam hazard', 'PPE'],
      fields: [
        BafModuleFieldSeed('waterConnectionCondition', 'Water connection condition', 'enum'),
        BafModuleFieldSeed('waterJacketLeakage', 'Water jacket leakage', 'enum'),
        BafModuleFieldSeed('TE05Reading', 'TE05 reading', 'numericWithUnit', unit: '°C'),
        BafModuleFieldSeed('FISL61Status', 'FISL61 status', 'enum'),
        BafModuleFieldSeed('pressureTestResult', 'Pressure-test result', 'enum'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-06-01', 'Inspect hoses/connectors and water jacket leakage.'),
        BafStandardJobItemSeed('B-06-02', 'Record flow/temperature alarm behavior and pressure-test result.'),
      ],
      addAsYouGoTriggers: ['Water leak', 'High cooling water temperature', 'Low flow alarm', 'Seal overheating risk'],
      closedDossierOutput: 'Leakage/pressure test status, flow/temperature alarms, repair status and readiness.',
    ),
    BafModuleSeed(
      moduleCode: 'B-07',
      moduleTitle: 'Base Instrumentation / Pressure Switches / Thermocouples',
      catalogueArea: 'Base',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Device integrity and PLC safety feedback',
      componentGroup: 'Base pressure/temperature/vibration instrumentation',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-51001'],
      operationalStatePreconditions: ['Device accessible and safe', 'Test does not create unsafe process state'],
      safetyConfirmations: ['Electrical/test-signal safety', 'LOTO if access requires isolation'],
      fields: [
        BafModuleFieldSeed('deviceTag', 'Device tag', 'deviceTagPicklist'),
        BafModuleFieldSeed('calibrationStatus', 'Calibration status', 'enum'),
        BafModuleFieldSeed('asFoundReading', 'As-found reading', 'numericWithUnit'),
        BafModuleFieldSeed('asLeftReading', 'As-left reading', 'numericWithUnit'),
        BafModuleFieldSeed('signalToPLCVerified', 'Signal to PLC verified', 'boolean'),
      ],
      standardItems: [
        BafStandardJobItemSeed('B-07-01', 'Verify pressure switches/transmitters/thermocouples and PLC signal response.'),
      ],
      addAsYouGoTriggers: ['Reading suspect', 'Calibration due', 'Safety interlock behavior needs proof'],
      closedDossierOutput: 'As-found/as-left, calibration/replacement, PLC signal verification and unresolved device risk.',
    ),

    // ─────────────────────────────────────────────────────────
    // INNER COVER
    // ─────────────────────────────────────────────────────────
    BafModuleSeed(
      moduleCode: 'IC-01',
      moduleTitle: 'Inner Cover Seal Area / Mating Surface',
      catalogueArea: 'Inner Cover',
      applicableAssetTypes: [AssetType.innerCover],
      functionalSection: 'Seal interface and leak integrity',
      componentGroup: 'Inner-cover seal/mating surface',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-18002'],
      operationalStatePreconditions: ['Inner cover accessible', 'Pressure test under controlled condition'],
      safetyConfirmations: ['Hot surface PPE', 'Pressure-test caution'],
      fields: [
        BafModuleFieldSeed('innerCoverSealCondition', 'Inner cover seal condition', 'enum'),
        BafModuleFieldSeed('matingSurfaceDamage', 'Mating surface damage', 'boolean'),
        BafModuleFieldSeed('leakTestResult', 'Leak-test result', 'enum'),
        BafModuleFieldSeed('cleaningDone', 'Cleaning done', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('IC-01-01', 'Clean and inspect seal area, rubber seal and mating surface.')],
      addAsYouGoTriggers: ['Base leak test suspects inner cover', 'Rust/scratch/foreign object found'],
      closedDossierOutput: 'Seal/mating-surface condition, leak-test findings and cleaning/repair action.',
    ),
    BafModuleSeed(
      moduleCode: 'IC-02',
      moduleTitle: 'Inner Cover Body / Barrel / Head / Lifting and Guide Hardware',
      catalogueArea: 'Inner Cover',
      applicableAssetTypes: [AssetType.innerCover],
      functionalSection: 'Structural integrity and safe handling',
      componentGroup: 'Inner-cover body and lifting hardware',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-18002'],
      operationalStatePreconditions: ['Inner cover cooled/accessible', 'Lifting device rated/engaged'],
      safetyConfirmations: ['Lifting risk controlled', 'Hot-equipment PPE'],
      fields: [
        BafModuleFieldSeed('liftingLugCondition', 'Lifting lug condition', 'enum'),
        BafModuleFieldSeed('coverCrackFound', 'Cover crack found', 'boolean'),
        BafModuleFieldSeed('distortionFound', 'Distortion found', 'boolean'),
        BafModuleFieldSeed('safeToLift', 'Safe to lift', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('IC-02-01', 'Inspect lifting lugs/ring/guide arms and cover cracks/distortion.')],
      addAsYouGoTriggers: ['Visible deformation', 'Lifting concern', 'Post-incident inspection'],
      closedDossierOutput: 'Structural condition, lifting fitness, repair need and safe-use status.',
    ),
    BafModuleSeed(
      moduleCode: 'IC-03',
      moduleTitle: 'Inner Cover Drain Spout / Plunger / Spring / Gasket',
      catalogueArea: 'Inner Cover',
      applicableAssetTypes: [AssetType.innerCover],
      functionalSection: 'Forced-cooler drain interface',
      componentGroup: 'Drain spout and plunger assembly',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.hotSurface,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['Inner cover removed or drain spout accessible', 'Cooler water drained as needed'],
      safetyConfirmations: ['Hot water/hot surface PPE', 'Spring/pinch hazard awareness'],
      fields: [
        BafModuleFieldSeed('plungerCondition', 'Plunger condition', 'enum'),
        BafModuleFieldSeed('springCondition', 'Spring condition', 'enum'),
        BafModuleFieldSeed('gasketCondition', 'Gasket condition', 'enum'),
        BafModuleFieldSeed('dripObserved', 'Water drip observed', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('IC-03-01', 'Inspect plunger, spring, gasket and drain-spout closure.')],
      addAsYouGoTriggers: ['Inner cover drips water when removed', 'Plunger/gasket/spring wear seen'],
      closedDossierOutput: 'Water-drip root cause, plunger/gasket/spring status and repair/replacement.',
    ),
    BafModuleSeed(
      moduleCode: 'IC-04',
      moduleTitle: 'Inner Cover Cooling Jacket / Water Connections / Fusible Plug',
      catalogueArea: 'Inner Cover',
      applicableAssetTypes: [AssetType.innerCover],
      functionalSection: 'Cooling jacket and explosion-prevention safety device',
      componentGroup: 'Cooling jacket / water connectors / fusible plug',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['CCH00002-000', 'FPM00001-000'],
      operationalStatePreconditions: ['Cooling system isolated', 'Replacement approved'],
      safetyConfirmations: ['Fusible plug shall not be substituted', 'Hot water/steam hazard', 'PPE'],
      fields: [
        BafModuleFieldSeed('waterConnectorCondition', 'Water connector condition', 'enum'),
        BafModuleFieldSeed('fusiblePlugStatus', 'Fusible plug status', 'enum'),
        BafModuleFieldSeed('coolingJacketLeakage', 'Cooling jacket leakage', 'enum'),
        BafModuleFieldSeed('replacementPartVerified', 'Replacement part verified', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('IC-04-01', 'Inspect water connectors, cooling jacket and fusible plug condition.')],
      addAsYouGoTriggers: ['Water connector dirty/worn', 'Fusible plug blown', 'Cooling jacket concern'],
      closedDossierOutput: 'Connector condition, fusible-plug condition, leakage risk and safe-return status.',
    ),
    BafModuleSeed(
      moduleCode: 'IC-05',
      moduleTitle: 'Inner Cover Purge / Interchangeability / Testing Support',
      catalogueArea: 'Inner Cover',
      applicableAssetTypes: [AssetType.innerCover, AssetType.base],
      functionalSection: 'Operational compatibility and test readiness',
      componentGroup: 'Inner-cover identity / compatibility / purge test',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.postRepairVerification,
      procedureRefs: ['SP-18001', 'SP-18003', 'SP-18100'],
      operationalStatePreconditions: ['Inner cover identity known', 'Compatible base/test jig verified'],
      safetyConfirmations: ['Purge/gas safety', 'Plant authorization'],
      fields: [
        BafModuleFieldSeed('innerCoverId', 'Inner cover ID', 'text'),
        BafModuleFieldSeed('compatibleBaseType', 'Compatible base type', 'text'),
        BafModuleFieldSeed('purgeStatus', 'Purge status', 'enum'),
        BafModuleFieldSeed('testJigUsed', 'Test jig used', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('IC-05-01', 'Record compatibility, purge/test result and restrictions.')],
      addAsYouGoTriggers: ['After repair', 'Suspected mismatch', 'Leak-test investigation', 'Configuration review'],
      closedDossierOutput: 'Compatibility status, purge/test notes and repair/test handover.',
    ),

    // ─────────────────────────────────────────────────────────
    // FURNACE
    // ─────────────────────────────────────────────────────────
    BafModuleSeed(
      moduleCode: 'F-01',
      moduleTitle: 'Furnace Combustion Air Blower / Air Piping / Air Flow',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Combustion-air supply and flow safety',
      componentGroup: 'Combustion air blower / FIT31 / FSL33 / PSL30',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.combustionSpecialist,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: ['SP-22005'],
      operationalStatePreconditions: ['Furnace safe to inspect', 'Blower/furnace control state known'],
      safetyConfirmations: ['Electrical isolation for blower', 'Combustion safety', 'Hot surface PPE'],
      fields: [
        BafModuleFieldSeed('blowerCondition', 'Blower condition', 'enum'),
        BafModuleFieldSeed('FIT31Reading', 'FIT31 reading', 'numericWithUnit'),
        BafModuleFieldSeed('FSL33Status', 'FSL33 status', 'enum'),
        BafModuleFieldSeed('PSL30Status', 'PSL30 status', 'enum'),
        BafModuleFieldSeed('airValvePosition', 'Air valve position', 'numericWithUnit', unit: '%'),
      ],
      standardItems: [BafStandardJobItemSeed('F-01-01', 'Inspect combustion air blower, piping and flow/pressure switch behavior.')],
      addAsYouGoTriggers: ['Furnace purge does not start', 'Combustion air blower fails', 'Air flow/pressure alarm'],
      closedDossierOutput: 'Air-path condition, blower availability, flow/pressure switch response and combustion readiness.',
    ),
    BafModuleSeed(
      moduleCode: 'F-02',
      moduleTitle: 'Furnace Mixed Fuel / Gas Valves / Gas Hose / Safety Shutoff',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Mixed fuel delivery and safety shutoff path',
      componentGroup: 'Fuel gas hose / shutoff valve path / PSH51 / PSL52',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: ['SP-20001', 'SP-22005', 'VAG00034', 'VAG00035'],
      operationalStatePreconditions: ['Fuel isolated or controlled test state', 'Authorized combustion/gas work only'],
      safetyConfirmations: ['Gas isolation', 'No smoking/open flame', 'Combustible gas awareness'],
      fields: [
        BafModuleFieldSeed('gasHoseCondition', 'Gas hose condition', 'enum'),
        BafModuleFieldSeed('PSH51Status', 'PSH51 status', 'enum'),
        BafModuleFieldSeed('PSL52Status', 'PSL52 status', 'enum'),
        BafModuleFieldSeed('FIT54Reading', 'FIT54 reading', 'numericWithUnit'),
        BafModuleFieldSeed('shutoffValveTestResult', 'Shutoff valve test result', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('F-02-01', 'Check fuel/gas valves, hose/coupling, pressure switches and shutoff behavior.')],
      addAsYouGoTriggers: ['No burners light', 'Fuel pressure alarm', 'Gas hose/coupling damaged', 'Gas valve PM due'],
      closedDossierOutput: 'Fuel/gas path condition, valve tightness/operation, pressure limits and hose/coupling status.',
    ),
    BafModuleSeed(
      moduleCode: 'F-03',
      moduleTitle: 'Furnace Burner / UV Detector / Igniter / Flame Supervision',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Burner ignition and flame proofing ecosystem',
      componentGroup: 'Burner / UV / ignition / flame supervision',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.combustionSpecialist,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: ['BUG00006/18', 'UVK00001', 'ECZ00086', 'ECP00002'],
      operationalStatePreconditions: ['Furnace cool for physical inspection or controlled firing observation'],
      safetyConfirmations: ['Combustion hazard controlled', 'Electrical ignition hazard controlled', 'Hot surface PPE'],
      fields: [
        BafModuleFieldSeed('burnerTarget', 'Burner target', 'targetRule', options: ['Burner 1', 'Burner 2', 'Burner 3', 'Burner 4', 'Burner 5', 'Burner 6', 'Burner 7', 'Burner 8']),
        BafModuleFieldSeed('UVCondition', 'UV detector condition', 'enum'),
        BafModuleFieldSeed('UVSignal', 'UV signal', 'numericWithUnit', unit: 'µA'),
        BafModuleFieldSeed('igniterGap', 'Igniter gap', 'numericWithUnit', unit: 'mm'),
        BafModuleFieldSeed('flameStatus', 'Flame status', 'enum'),
        BafModuleFieldSeed('burnerBlockCondition', 'Burner block / firing tube condition', 'enum'),
      ],
      standardItems: [
        BafStandardJobItemSeed('F-03-01', 'Check UV detector/lens/signal and burner target.'),
        BafStandardJobItemSeed('F-03-02', 'Inspect igniter, ignition cable, connector and burner parts.'),
        BafStandardJobItemSeed('F-03-03', 'Observe the numbered burner block and firing tube for red heat, missing castable or cracking; involve Mechanical for physical investigation or replacement.'),
      ],
      addAsYouGoTriggers: ['Burner fails to light', 'All burners do not light', 'Flame out', 'Weak UV or dirty lens suspected', 'Burner block red hot', 'Burner block or firing tube damaged'],
      closedDossierOutput: 'Burner-wise I&A investigation, weak UV/flame issues, ignition component status and any Mechanical follow-up requirement.',
    ),
    BafModuleSeed(
      moduleCode: 'F-03M',
      moduleTitle: 'Furnace Burner Block Investigation and Mechanical Replacement',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Burner-block investigation, installation and lifecycle',
      componentGroup: 'Burner block / firing tube',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.combustionSpecialist,
      defaultUseMode: JobModuleUseMode.shutdownWork,
      procedureRefs: ['7-1-13-0028-41-1012 §4.3'],
      operationalStatePreconditions: ['Furnace removed, cooled and safe for burner access', 'Fuel isolated before burner-block work'],
      safetyConfirmations: ['Fuel isolation confirmed', 'Hot-surface exposure controlled', 'Refractory handling and lifting controls applied'],
      fields: [
        BafModuleFieldSeed('burnerTarget', 'Burner target', 'targetRule', required: true, options: ['Burner 1', 'Burner 2', 'Burner 3', 'Burner 4', 'Burner 5', 'Burner 6', 'Burner 7', 'Burner 8']),
        BafModuleFieldSeed('burnerBlockAsFound', 'Burner block / firing tube as found', 'enum', required: true, options: ['Healthy', 'Red hot', 'Missing castable', 'Cracked', 'Other damage']),
        BafModuleFieldSeed('burnerBlockChanged', 'Burner block changed', 'boolean', required: true),
        BafModuleFieldSeed('supplyRoute', 'Replacement supply route', 'enum', options: ['SAIL-made by RED', 'Purchased']),
        BafModuleFieldSeed('supplierName', 'Supplier name (purchased, optional)', 'text'),
        BafModuleFieldSeed('purchaseOrderNumber', 'PO number (purchased, optional)', 'text'),
      ],
      standardItems: [
        BafStandardJobItemSeed('F-03M-01', 'Mechanically investigate the selected burner block and firing tube for red heat, missing castable, cracking and other damage.'),
        BafStandardJobItemSeed('F-03M-02', 'When changed, Mechanical must add a governed Replacement component action with burner position, SAIL-made-by-RED or Purchased source, and optional supplier/PO evidence.'),
        BafStandardJobItemSeed('F-03M-03', 'Confirm the mechanically installed block and firing tube are serviceable before module submission.'),
      ],
      addAsYouGoTriggers: ['Burner block red hot', 'Burner block cracked', 'Castable missing', 'Firing tube damaged', 'Block replacement during shutdown'],
      closedDossierOutput: 'Mechanical as-found and installation evidence, burner position, SAIL-made-by-RED or purchased provenance, optional supplier/PO and automatic Furnace audit update.',
    ),
    BafModuleSeed(
      moduleCode: 'F-04',
      moduleTitle: 'Furnace Draft Seal / Casing / Insulation / Downcomer',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Waste-gas containment and hot structure',
      componentGroup: 'Draft seal / casing / insulation / downcomer',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.hotSurface,
      defaultUseMode: JobModuleUseMode.shutdownWork,
      procedureRefs: ['SP-21200'],
      operationalStatePreconditions: ['Furnace removed/cooled or safe to access', 'Lifting controls verified'],
      safetyConfirmations: ['Hot surface/burn risk controlled', 'Waste-gas awareness', 'Lifting precautions'],
      fields: [
        BafModuleFieldSeed('draftSealCondition', 'Draft seal condition', 'enum'),
        BafModuleFieldSeed('insulationCondition', 'Insulation condition', 'enum'),
        BafModuleFieldSeed('casingDamage', 'Casing damage', 'boolean'),
        BafModuleFieldSeed('downcomerCondition', 'Downcomer condition', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('F-04-01', 'Inspect/replace draft seal and inspect casing/insulation/downcomer.')],
      addAsYouGoTriggers: ['Draft seal worn', 'Waste gas escape suspected', 'Casing/insulation damage observed'],
      closedDossierOutput: 'Draft-seal condition, casing/insulation status, replacement/repair and waste-gas leak risk.',
    ),
    BafModuleSeed(
      moduleCode: 'F-05',
      moduleTitle: 'Furnace Combustion Settings / Control Valves / Linkage',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Mass-flow combustion tuning and control feedback',
      componentGroup: 'Air/fuel control valves and linkage',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.combustionSpecialist,
      defaultUseMode: JobModuleUseMode.postRepairVerification,
      procedureRefs: ['SP-22005'],
      operationalStatePreconditions: ['Furnace installed over appropriate base/product', 'Purged and running under authorized conditions when setting combustion'],
      safetyConfirmations: ['Combustion specialist authorization', 'Gas/air pressure safety'],
      fields: [
        BafModuleFieldSeed('combustionSettingStatus', 'Combustion setting status', 'enum'),
        BafModuleFieldSeed('airValvePosition', 'Air valve position', 'numericWithUnit', unit: '%'),
        BafModuleFieldSeed('fuelValvePosition', 'Fuel valve position', 'numericWithUnit', unit: '%'),
        BafModuleFieldSeed('airDP', 'Air differential pressure', 'numericWithUnit'),
        BafModuleFieldSeed('fuelDP', 'Fuel differential pressure', 'numericWithUnit'),
      ],
      standardItems: [BafStandardJobItemSeed('F-05-01', 'Record air/fuel settings, linkage condition and as-found/as-left readings.')],
      addAsYouGoTriggers: ['Combustion settings due', 'Burners flame out', 'Fuel/air controls repaired', 'Inconsistent firing'],
      closedDossierOutput: 'As-found/as-left combustion settings, linkage condition, flue-gas observation and reset status.',
    ),
    BafModuleSeed(
      moduleCode: 'F-06',
      moduleTitle: 'Furnace Thermocouples / High Limit / Furnace Safety Systems',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Temperature and safety interlock chain',
      componentGroup: 'TE00 / TE01 / high limit / furnace safety',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-51001'],
      operationalStatePreconditions: ['Furnace safe for device access', 'Test does not bypass safety protection'],
      safetyConfirmations: ['Do not defeat safety limits', 'Electrical/test-signal safety', 'Hot surface PPE'],
      fields: [
        BafModuleFieldSeed('deviceTag', 'Device tag', 'deviceTagPicklist', options: ['TE00', 'TE01']),
        BafModuleFieldSeed('highLimitStatus', 'High-limit status', 'enum'),
        BafModuleFieldSeed('safetyShutdownVerified', 'Safety shutdown verified', 'boolean'),
        BafModuleFieldSeed('replacementDone', 'Replacement done', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('F-06-01', 'Verify furnace thermocouples, high-limit status and safety shutdown behavior.')],
      addAsYouGoTriggers: ['High-limit trip', 'Furnace shuts off', 'Thermocouple failure suspected', 'Annual replacement due'],
      closedDossierOutput: 'Safety-system verification, thermocouple replacement and alarm/shutdown proof.',
    ),
    BafModuleSeed(
      moduleCode: 'F-07',
      moduleTitle: 'Furnace Control Panel / Power Plug / Relay / Motor Starter',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Electrical control and plug integrity',
      componentGroup: 'Furnace panel / plug / relay / motor starter',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Panel safe to inspect', 'Furnace plugged/unplugged condition recorded'],
      safetyConfirmations: ['Electrical isolation', 'E-stop awareness', 'Panel safety'],
      fields: [
        BafModuleFieldSeed('relayCondition', 'Relay condition', 'enum'),
        BafModuleFieldSeed('motorStarterTripResult', 'Motor starter trip result', 'enum'),
        BafModuleFieldSeed('powerPlugCondition', 'Power plug condition', 'enum'),
        BafModuleFieldSeed('controlPlugCondition', 'Control plug condition', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('F-07-01', 'Inspect relays, motor starter, power/control plugs and cable fault evidence.')],
      addAsYouGoTriggers: ['Furnace blower will not start', 'Furnace plug defective', 'Relay/starter fault suspected'],
      closedDossierOutput: 'Electrical control condition, relay/starter status and plug/cable fault findings.',
    ),
    BafModuleSeed(
      moduleCode: 'F-08',
      moduleTitle: 'Furnace Lifting / Transport / Handling Interface',
      catalogueArea: 'Furnace',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Crane-handled furnace movement safety',
      componentGroup: 'Furnace lifting eye / guide arm / transport',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Furnace movement planned/complete', 'Crane/lifting authorization confirmed'],
      safetyConfirmations: ['Overhead-load exclusion', 'Hot-surface PPE', 'Lifting-device safety'],
      fields: [
        BafModuleFieldSeed('liftingEyeCondition', 'Lifting eye condition', 'enum'),
        BafModuleFieldSeed('guideArmCondition', 'Guide arm condition', 'enum'),
        BafModuleFieldSeed('transportDamage', 'Transport damage', 'boolean'),
        BafModuleFieldSeed('restrictionStatus', 'Restriction status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('F-08-01', 'Inspect lifting eye, guide arm and transport damage before use.')],
      addAsYouGoTriggers: ['Scheduled lifting inspection', 'Furnace mishandling', 'Abnormal placement', 'Guide/damper alignment issue'],
      closedDossierOutput: 'Lifting fitness, guide alignment, post-transport damage and safe placement status.',
    ),

    // ─────────────────────────────────────────────────────────
    // FORCED COOLER
    // ─────────────────────────────────────────────────────────
    BafModuleSeed(
      moduleCode: 'FC-01',
      moduleTitle: 'Forced Cooler Water Hose / Valve / Flow Switch',
      catalogueArea: 'Forced Cooler',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Water supply and low-flow safety',
      componentGroup: 'Water hose / YIV60 / FISL61',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooler installed or safe access to water connectors', 'PLC water-call state known'],
      safetyConfirmations: ['Water pressure/hot water safety', 'PPE'],
      fields: [
        BafModuleFieldSeed('waterHoseCondition', 'Water hose condition', 'enum'),
        BafModuleFieldSeed('couplingSeated', 'Coupling seated', 'boolean'),
        BafModuleFieldSeed('flowRate', 'Flow rate', 'numericWithUnit'),
        BafModuleFieldSeed('flowSwitchStatus', 'Flow switch status', 'enum'),
        BafModuleFieldSeed('YIV60Status', 'YIV60 status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('FC-01-01', 'Check water valves, hose/coupling, flow switch action and PLC response.')],
      addAsYouGoTriggers: ['Cannot get recommended water flow', 'Flow switch alarm', 'Valve stuck/closed', 'Water coupling issue'],
      closedDossierOutput: 'Water-flow readiness, coupling/valve condition, PLC alarm response and corrective action.',
    ),
    BafModuleSeed(
      moduleCode: 'FC-02',
      moduleTitle: 'Forced Cooler Spray Nozzles / Water Manifolds / Cleanouts',
      catalogueArea: 'Forced Cooler',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Spray distribution and cooling effectiveness',
      componentGroup: 'Spray nozzles / manifolds / cleanouts',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooler safe for internal inspection/cleanout', 'Water isolated as needed'],
      safetyConfirmations: ['Water pressure released', 'Access safety', 'PPE'],
      fields: [
        BafModuleFieldSeed('nozzleCondition', 'Nozzle condition', 'enum'),
        BafModuleFieldSeed('blockedNozzles', 'Blocked nozzles', 'multiSelect'),
        BafModuleFieldSeed('nozzlesCleaned', 'Nozzles cleaned', 'boolean'),
        BafModuleFieldSeed('nozzleReplaced', 'Nozzle replaced', 'boolean'),
        BafModuleFieldSeed('manifoldCondition', 'Manifold condition', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('FC-02-01', 'Inspect, rod/clean and replace blocked spray nozzles as required.')],
      addAsYouGoTriggers: ['Poor cooling', 'Low flow due to obstruction', 'Blocked nozzles found', 'Nozzle cleaning due'],
      closedDossierOutput: 'Nozzle blockage map, cleaned/replaced nozzles and manifold condition.',
    ),
    BafModuleSeed(
      moduleCode: 'FC-03',
      moduleTitle: 'Forced Cooler Blowers / Motors / Fan Inlets',
      catalogueArea: 'Forced Cooler',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Air cooling and blower availability',
      componentGroup: 'Blower motors / fan inlets / overloads',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.lotoRequired,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooler blower locked out for physical inspection', 'Control state known'],
      safetyConfirmations: ['Electrical isolation', 'Rotating equipment hazard controlled', 'LOTO before fan/motor inspection'],
      fields: [
        BafModuleFieldSeed('blower1Status', 'Blower 1 status', 'enum'),
        BafModuleFieldSeed('blower2Status', 'Blower 2 status', 'enum'),
        BafModuleFieldSeed('overloadStatus', 'Overload status', 'enum'),
        BafModuleFieldSeed('fanObstruction', 'Fan obstruction', 'boolean'),
        BafModuleFieldSeed('vibrationObserved', 'Vibration observed', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('FC-03-01', 'Inspect blower/fan damage, balance, obstruction and motor overload cause.')],
      addAsYouGoTriggers: ['One or both blowers do not run', 'Overload trip', 'Obstruction suspected', 'Vibration observed'],
      closedDossierOutput: 'Blower availability, balance/vibration status and motor/overload findings.',
    ),
    BafModuleSeed(
      moduleCode: 'FC-04',
      moduleTitle: 'Forced Cooler Casing / Lifting Eye / Guide and Striker Arm',
      catalogueArea: 'Forced Cooler',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Structure, handling and inner-cover drain engagement',
      componentGroup: 'Cooler casing / lifting / striker arm',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooler accessible', 'Not under unsafe suspended load'],
      safetyConfirmations: ['Lifting risk controlled', 'Overhead-load precautions', 'Hot equipment awareness'],
      fields: [
        BafModuleFieldSeed('casingCondition', 'Casing condition', 'enum'),
        BafModuleFieldSeed('liftingEyeCondition', 'Lifting eye condition', 'enum'),
        BafModuleFieldSeed('strikerArmCondition', 'Striker arm condition', 'enum'),
        BafModuleFieldSeed('repairRequired', 'Repair required', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('FC-04-01', 'Inspect casing, legs, ducts, striker arm, lifting eye and guide condition.')],
      addAsYouGoTriggers: ['Cooler mishandled', 'Striker arm does not engage drain spout', 'Structural damage observed'],
      closedDossierOutput: 'Structural condition, lifting fitness, striker/drain engagement and repair status.',
    ),
    BafModuleSeed(
      moduleCode: 'FC-05',
      moduleTitle: 'Forced Cooler Draining / Removal Readiness',
      catalogueArea: 'Forced Cooler',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Safe removal and water carryover prevention',
      componentGroup: 'Drain valve / removal readiness',
      defaultDiscipline: JobModuleDiscipline.operations,
      defaultSafetyClass: JobModuleSafetyClass.hotSurface,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooling/removal sequence reached', 'Drain time and operator action recorded'],
      safetyConfirmations: ['Hot water/drip risk controlled', 'PPE', 'Drain confirmation'],
      fields: [
        BafModuleFieldSeed('drainConfirmed', 'Drain confirmed', 'boolean'),
        BafModuleFieldSeed('drainDurationSeconds', 'Drain duration', 'numericWithUnit', unit: 's'),
        BafModuleFieldSeed('excessWaterObserved', 'Excess water observed', 'boolean'),
        BafModuleFieldSeed('removalReady', 'Removal ready', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('FC-05-01', 'Confirm cooler drain before removal and document excess water/drain fault.')],
      addAsYouGoTriggers: ['Cooler drips excess water', 'Shift handover before removal', 'Removal readiness confirmation required'],
      closedDossierOutput: 'Drain confirmation, excess water reason and handover note.',
    ),

    // ─────────────────────────────────────────────────────────
    // SHARED SUPPORT MODULES FROM V0.2
    // ─────────────────────────────────────────────────────────
    BafModuleSeed(
      moduleCode: 'AU-01',
      moduleTitle: 'Analyzer Readings / Sample Line / Analyzer Panel Filters',
      catalogueArea: 'Automation',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Analyzer health and sample integrity',
      componentGroup: 'Analyzer panel / sample line / filters',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-56100', 'SP-56200'],
      operationalStatePreconditions: ['Analyzer panel safe to access', 'Sample gas path isolated where procedure requires'],
      safetyConfirmations: ['Gas sample safety', 'Calibration gas handling', 'PPE'],
      fields: [
        BafModuleFieldSeed('analyzerId', 'Analyzer ID', 'text'),
        BafModuleFieldSeed('readingValue', 'Reading value', 'numericWithUnit'),
        BafModuleFieldSeed('sampleFlow', 'Sample flow', 'numericWithUnit'),
        BafModuleFieldSeed('calibrationStatus', 'Calibration status', 'enum'),
        BafModuleFieldSeed('filterCondition', 'Filter condition', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AU-01-01', 'Verify analyzer readings, filters, sample flow and calibration status.')],
      addAsYouGoTriggers: ['Analyzer reading suspect', 'Purge/hydrogen permissive issue', 'Filter due', 'CARI-meter service due'],
      closedDossierOutput: 'Analyzer readiness, filter/sample condition and calibration status.',
    ),
    BafModuleSeed(
      moduleCode: 'AU-02',
      moduleTitle: 'PLC Analog Inputs / Digital I/O / Device Simulation',
      catalogueArea: 'Automation',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'PLC signal integrity',
      componentGroup: 'PLC I/O / field device signal',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.postRepairVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Test authorized', 'Simulation will not create unsafe plant condition'],
      safetyConfirmations: ['Electrical/test-signal safety', 'No unsafe forced outputs'],
      fields: [
        BafModuleFieldSeed('deviceTag', 'Device tag', 'deviceTagPicklist'),
        BafModuleFieldSeed('simulatedValue', 'Simulated value', 'numericWithUnit'),
        BafModuleFieldSeed('PLCDisplayedValue', 'PLC displayed value', 'numericWithUnit'),
        BafModuleFieldSeed('signalVerified', 'Signal verified', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AU-02-01', 'Simulate device signal and verify PLC value/alarm/action.')],
      addAsYouGoTriggers: ['Screen value XXX', 'Signal mismatch', 'Post-repair validation', 'I/O verification due'],
      closedDossierOutput: 'Signal verification, as-found/as-left and unresolved I/O risk.',
    ),
    BafModuleSeed(
      moduleCode: 'AU-03',
      moduleTitle: 'PLC Panel Power Supplies / E-Stop / UPS',
      catalogueArea: 'Automation',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Control power and emergency reliability',
      componentGroup: 'PLC panel power / E-stop / UPS',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['Panel access authorized', 'E-stop/UPS tests coordinated with operations'],
      safetyConfirmations: ['Electrical safety', 'E-stop test authorization', 'UPS power-change caution'],
      fields: [
        BafModuleFieldSeed('panelId', 'Panel ID', 'text'),
        BafModuleFieldSeed('voltageReading', 'Voltage reading', 'numericWithUnit', unit: 'V'),
        BafModuleFieldSeed('EStopVerified', 'E-stop verified', 'boolean'),
        BafModuleFieldSeed('UPSRuntime', 'UPS runtime', 'numericWithUnit', unit: 'min'),
      ],
      standardItems: [BafStandardJobItemSeed('AU-03-01', 'Verify PLC panel supply voltages, E-stop response and UPS behavior.')],
      addAsYouGoTriggers: ['Power instability', 'E-stop concern', 'UPS maintenance due', 'Scheduled safety verification'],
      closedDossierOutput: 'Control-power health, E-stop function, UPS operation and test evidence.',
    ),
    BafModuleSeed(
      moduleCode: 'AU-04',
      moduleTitle: 'Server / RSView / CAPS Backup and Restore Readiness',
      catalogueArea: 'Automation',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Supervisory system resilience',
      componentGroup: 'Server / RSView / CAPS / Wyse thin client',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.configurationControl,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: ['SP-53000', 'SP-53002'],
      operationalStatePreconditions: ['Workstation/server accessible', 'Backup window approved'],
      safetyConfirmations: ['IT/control-system change control', 'Backup media security'],
      fields: [
        BafModuleFieldSeed('backupCompleted', 'Backup completed', 'boolean'),
        BafModuleFieldSeed('backupLocation', 'Backup location', 'text'),
        BafModuleFieldSeed('configVersion', 'Configuration version', 'text'),
        BafModuleFieldSeed('restoreTested', 'Restore tested', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AU-04-01', 'Perform backup and record configuration/restore readiness.')],
      addAsYouGoTriggers: ['Scheduled backup', 'Configuration change', 'Workstation instability', 'Post-recovery validation'],
      closedDossierOutput: 'Backup status, restore readiness and configuration snapshot.',
    ),
    BafModuleSeed(
      moduleCode: 'AU-05',
      moduleTitle: 'Communication / Operator Screen / Alarm and Event Diagnosis',
      catalogueArea: 'Automation',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'HMI and PLC communication health',
      componentGroup: 'Operator screen / alarm / event / Ethernet',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.configurationControl,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Troubleshooting authorized', 'Affected base/system identified'],
      safetyConfirmations: ['Control-room/change-control safety', 'No unsafe bypass'],
      fields: [
        BafModuleFieldSeed('screenAffected', 'Screen affected', 'text'),
        BafModuleFieldSeed('commFailureType', 'Communication failure type', 'enum'),
        BafModuleFieldSeed('PLCModuleStatus', 'PLC module status', 'enum'),
        BafModuleFieldSeed('recoveryVerified', 'Recovery verified', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AU-05-01', 'Diagnose affected screens, comm failure, PLC module and recovery status.')],
      addAsYouGoTriggers: ['Analog values display XXX', 'PLC CPU/I/O fault', 'Computer lockup', 'Partial base communication failure'],
      closedDossierOutput: 'Communication root cause, affected screens/bases, repair and recovery status.',
    ),

    BafModuleSeed(
      moduleCode: 'AT-01',
      moduleTitle: 'Hydrogen Valve Leak Test / Safety Shutoff Valves',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace],
      functionalSection: 'Hydrogen containment and permissive safety',
      componentGroup: 'YV45 / FOV46A-B / PCV47 / PSL47',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Leak-test sequence authorized', 'Valve stand in safe leak-test state'],
      safetyConfirmations: ['Hydrogen/fire/explosion risk controlled', 'No smoking/open flame', 'Gas detector as per plant rules'],
      fields: [
        BafModuleFieldSeed('leakTestResult', 'Leak-test result', 'enum'),
        BafModuleFieldSeed('testPressure', 'Test pressure', 'numericWithUnit'),
        BafModuleFieldSeed('YV45Status', 'YV45 status', 'enum'),
        BafModuleFieldSeed('FOV46AStatus', 'FOV46A status', 'enum'),
        BafModuleFieldSeed('FOV46BStatus', 'FOV46B status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-01-01', 'Record hydrogen valve leak-test result and failed valve/piping diagnosis.')],
      addAsYouGoTriggers: ['Hydrogen leak test fails', 'Hydrogen will not start', 'Valve does not actuate', 'Pre-cycle proof required'],
      closedDossierOutput: 'Valve leak-test result, failed valve/piping diagnosis and closure readiness.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-02',
      moduleTitle: 'Nitrogen Purge / Sheath Purge / Motor Purge',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.innerCover],
      functionalSection: 'Nitrogen purge and inerting path',
      componentGroup: 'YIV25 / FSL25 / FIT25 / FSL26 / YV26-YV27',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Purge state known', 'Nitrogen supply available', 'Manual valve status verified'],
      safetyConfirmations: ['Nitrogen asphyxiation risk controlled', 'Confined/tunnel gas awareness', 'PPE'],
      fields: [
        BafModuleFieldSeed('nitrogenValveOpen', 'Nitrogen valve open', 'boolean'),
        BafModuleFieldSeed('FIT25Flow', 'FIT25 flow', 'numericWithUnit'),
        BafModuleFieldSeed('FSL25Status', 'FSL25 status', 'enum'),
        BafModuleFieldSeed('FSL26Status', 'FSL26 status', 'enum'),
        BafModuleFieldSeed('purgeStatus', 'Purge status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-02-01', 'Verify nitrogen manual valve, purge flow, sheath/motor purge and low-flow alarms.')],
      addAsYouGoTriggers: ['No nitrogen flow', 'Purge disabled', 'Hydrogen permissive blocked', 'Manual valve closed'],
      closedDossierOutput: 'Purge flow status, manual valve/proximity status and purge failure cause.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-03',
      moduleTitle: 'Inner Cover Pressure Control / Relief / Back Pressure',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.innerCover],
      functionalSection: 'Pressure containment under inner cover',
      componentGroup: 'PT74 / PSH71 / PSL75 / PSL76 / PCV70 / PCV77',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Base/inner cover pressure state controlled', 'Valves accessible'],
      safetyConfirmations: ['Pressure/gas safety', 'Relief system caution'],
      fields: [
        BafModuleFieldSeed('PT74Reading', 'PT74 reading', 'numericWithUnit'),
        BafModuleFieldSeed('PSH71Status', 'PSH71 status', 'enum'),
        BafModuleFieldSeed('PSL75Status', 'PSL75 status', 'enum'),
        BafModuleFieldSeed('PSL76Status', 'PSL76 status', 'enum'),
        BafModuleFieldSeed('alarmAction', 'Alarm action verified', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-03-01', 'Record pressure, switches, relief/back-pressure status and root cause.')],
      addAsYouGoTriggers: ['Base fails leak test', 'Pressure too high/low', 'Hydrogen will not start', 'Back-pressure issue'],
      closedDossierOutput: 'Pressure readings, switch behavior, relief/back-pressure condition and root cause.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-04',
      moduleTitle: 'Atmosphere Piping / Exhaust / Waste Gas / Condensate',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.innerCover],
      functionalSection: 'Piping integrity and exhaust path',
      componentGroup: 'Atmosphere/exhaust piping / waste gas / drains',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Piping accessible', 'Gas state safe or test authorized'],
      safetyConfirmations: ['Gas leak/exhaust/asphyxiation risk controlled', 'Combustible detector as required'],
      fields: [
        BafModuleFieldSeed('pipingCondition', 'Piping condition', 'enum'),
        BafModuleFieldSeed('drainStatus', 'Drain status', 'enum'),
        BafModuleFieldSeed('exhaustValveStatus', 'Exhaust valve status', 'enum'),
        BafModuleFieldSeed('gasDetectorUsed', 'Gas detector used', 'boolean'),
        BafModuleFieldSeed('leakLocation', 'Leak location', 'text'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-04-01', 'Inspect/rod/clean lines and verify exhaust valve/pressure response.')],
      addAsYouGoTriggers: ['Leak test pressure loss', 'Atmosphere flow abnormal', 'Gas odor/detector alarm', 'Condensate blockage'],
      closedDossierOutput: 'Piping condition, leak/blockage source and exhaust valve status.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-05',
      moduleTitle: 'Hobre WDM 3300 CARI-meter / Mixed Gas Analyzer Service',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.furnace, AssetType.base],
      functionalSection: 'Mixed fuel quality/analyzer service',
      componentGroup: 'CARI-meter / mixed gas analyzer',
      defaultDiscipline: JobModuleDiscipline.instrumentation,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['Analyzer safe to service', 'Sample line isolated as required'],
      safetyConfirmations: ['Gas/calibration-gas safety', 'Analyzer service authorization'],
      fields: [
        BafModuleFieldSeed('CARIStatus', 'CARI-meter status', 'enum'),
        BafModuleFieldSeed('sampleFlow', 'Sample flow', 'numericWithUnit'),
        BafModuleFieldSeed('calibrationGasStatus', 'Calibration gas status', 'enum'),
        BafModuleFieldSeed('oxygenReading', 'Oxygen reading', 'numericWithUnit'),
        BafModuleFieldSeed('filterStatus', 'Filter status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-05-01', 'Check flows, calibration, oxygen cell/board, filters and configurator status.')],
      addAsYouGoTriggers: ['Analyzer calibration due', 'Gas composition issue', 'CARI-meter alarm', 'Mixed gas troubleshooting'],
      closedDossierOutput: 'Analyzer health, calibration status and component revision/replacement.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-06',
      moduleTitle: 'Pressure Reducing Station / Headers / Regulators / Strainers',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.innerCover],
      functionalSection: 'Utility gas pressure supply integrity',
      componentGroup: 'H2/N2 pressure station / regulators / strainers',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Station accessible', 'Isolated per plant procedure where needed'],
      safetyConfirmations: ['High-pressure gas safety', 'Regulator relief risk', 'PPE'],
      fields: [
        BafModuleFieldSeed('headerPressure', 'Header pressure', 'numericWithUnit'),
        BafModuleFieldSeed('regulatorStatus', 'Regulator status', 'enum'),
        BafModuleFieldSeed('strainerCondition', 'Strainer condition', 'enum'),
        BafModuleFieldSeed('manualValveStatus', 'Manual valve status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-06-01', 'Verify header pressures, regulators, strainers and relief/manual valves.')],
      addAsYouGoTriggers: ['High/low nitrogen or hydrogen pressure', 'No nitrogen flow', 'Hydrogen blocked', 'Station PM due'],
      closedDossierOutput: 'Header pressure status, regulator/strainer condition and supply readiness.',
    ),
    BafModuleSeed(
      moduleCode: 'AT-07',
      moduleTitle: 'Hydrogen / Nitrogen / Mixed Fuel Safety Monitoring',
      catalogueArea: 'Atmosphere / Flow Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Gas-risk monitoring and emergency readiness',
      componentGroup: 'Gas detector / utility monitoring / escalation',
      defaultDiscipline: JobModuleDiscipline.safety,
      defaultSafetyClass: JobModuleSafetyClass.gasRisk,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Area access permitted', 'Detector available/calibrated'],
      safetyConfirmations: ['Hydrogen explosion risk', 'Nitrogen asphyxiation risk', 'No smoking/open flames'],
      fields: [
        BafModuleFieldSeed('detectorUsed', 'Detector used', 'boolean'),
        BafModuleFieldSeed('detectorReading', 'Detector reading', 'numericWithUnit'),
        BafModuleFieldSeed('gasType', 'Gas type', 'enum', options: ['Hydrogen', 'Nitrogen', 'Mixed fuel', 'Unknown']),
        BafModuleFieldSeed('location', 'Location', 'text'),
        BafModuleFieldSeed('areaRestricted', 'Area restricted', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AT-07-01', 'Record detector use, monitored status, escalation and area restriction.')],
      addAsYouGoTriggers: ['Gas odor/suspected leak', 'Failed hot leak test', 'Tunnel/asphyxiation concern', 'Utility alarm'],
      closedDossierOutput: 'Gas safety check record, detector use and escalation/handover.',
    ),

    BafModuleSeed(
      moduleCode: 'MC-01',
      moduleTitle: 'MCC / VFD Visual and Warning Inspection',
      catalogueArea: 'Motor Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler],
      functionalSection: 'Drive and MCC health',
      componentGroup: 'MCC / VFD / drive parameters',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.scheduledPM,
      procedureRefs: [],
      operationalStatePreconditions: ['MCC/VFD safe to inspect', 'No unsafe live work beyond authorization'],
      safetyConfirmations: ['Qualified access', 'Electrical safety', 'Panel PPE as applicable'],
      fields: [
        BafModuleFieldSeed('VFDWarning', 'VFD warning', 'text'),
        BafModuleFieldSeed('MCCCondition', 'MCC condition', 'enum'),
        BafModuleFieldSeed('parameterMatch', 'Parameters match factory setting', 'boolean'),
        BafModuleFieldSeed('damageObserved', 'Damage observed', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('MC-01-01', 'Check VFD display warnings, MCC condition and drive parameter match.')],
      addAsYouGoTriggers: ['Drive warning', 'Motor start issue', 'Scheduled PM', 'Post-drive replacement verification'],
      closedDossierOutput: 'Drive warnings, visual damage, parameter match and corrective action.',
    ),
    BafModuleSeed(
      moduleCode: 'MC-02',
      moduleTitle: 'Wiring / Jumpers / Pilot Lights / Pushbuttons',
      catalogueArea: 'Motor Control',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Control wiring and operator interface integrity',
      componentGroup: 'Wiring / pilot lights / pushbuttons / PLC signal',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Panel/control station accessible', 'Test authorization'],
      safetyConfirmations: ['Electrical isolation or qualified live testing', 'Panel safety'],
      fields: [
        BafModuleFieldSeed('wiringCondition', 'Wiring condition', 'enum'),
        BafModuleFieldSeed('jumperFound', 'Jumper found', 'boolean'),
        BafModuleFieldSeed('pushbuttonStatus', 'Pushbutton status', 'enum'),
        BafModuleFieldSeed('pilotLightStatus', 'Pilot light status', 'enum'),
        BafModuleFieldSeed('PLCSignalReceived', 'PLC signal received', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('MC-02-01', 'Inspect wiring/jumpers/lights/pushbuttons and verify PLC signal path.')],
      addAsYouGoTriggers: ['Command fails', 'Pilot indication wrong', 'Panel inspection due'],
      closedDossierOutput: 'Wiring/control-station condition and failed input root cause.',
    ),
    BafModuleSeed(
      moduleCode: 'MC-03',
      moduleTitle: 'Base Fan Motor Control Troubleshooting',
      catalogueArea: 'Motor Control',
      applicableAssetTypes: [AssetType.base],
      functionalSection: 'Base fan electrical permissive chain',
      componentGroup: 'Base fan MCC / VFD / starter / E-stop',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Base fan command state known', 'E-stop/disconnect checked'],
      safetyConfirmations: ['Electrical safety', 'Rotating equipment safety', 'LOTO where mechanical check required'],
      fields: [
        BafModuleFieldSeed('baseFanStartStatus', 'Base fan start status', 'enum'),
        BafModuleFieldSeed('EStopStatus', 'E-stop status', 'enum'),
        BafModuleFieldSeed('starterStatus', 'Starter status', 'enum'),
        BafModuleFieldSeed('VFDStatus', 'VFD status', 'enum'),
        BafModuleFieldSeed('auxBlowerPower', 'Aux blower power', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('MC-03-01', 'Check base fan disconnects, starter/VFD, E-stop, PLC cause and aux blower.')],
      addAsYouGoTriggers: ['Base fan will not start', 'Base fan trips repeatedly'],
      closedDossierOutput: 'Electrical cause of fan start failure and recovery proof.',
    ),
    BafModuleSeed(
      moduleCode: 'MC-04',
      moduleTitle: 'Furnace Combustion Air Blower Control Troubleshooting',
      catalogueArea: 'Motor Control',
      applicableAssetTypes: [AssetType.furnace],
      functionalSection: 'Furnace blower electrical permissive chain',
      componentGroup: 'Furnace blower MCC / starter / plugs / E-stop',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Furnace control state known', 'Gas safety considered before start attempts'],
      safetyConfirmations: ['Electrical safety', 'Combustion safety', 'E-stop awareness'],
      fields: [
        BafModuleFieldSeed('furnaceBlowerStartStatus', 'Furnace blower start status', 'enum'),
        BafModuleFieldSeed('plugCondition', 'Plug condition', 'enum'),
        BafModuleFieldSeed('starterStatus', 'Starter status', 'enum'),
        BafModuleFieldSeed('EStopStatus', 'E-stop status', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('MC-04-01', 'Check furnace blower MCC/starter, plugs, E-stop and PLC/furnace safety cause.')],
      addAsYouGoTriggers: ['Furnace combustion air blower will not start', 'Purge cannot begin'],
      closedDossierOutput: 'Blower start cause, plug/control issue and recovery proof.',
    ),
    BafModuleSeed(
      moduleCode: 'MC-05',
      moduleTitle: 'Forced Cooler Blower Control Troubleshooting',
      catalogueArea: 'Motor Control',
      applicableAssetTypes: [AssetType.forceCooler],
      functionalSection: 'Forced-cooler blower electrical permissive chain',
      componentGroup: 'Forced cooler fan plugs / starters / overloads',
      defaultDiscipline: JobModuleDiscipline.electrical,
      defaultSafetyClass: JobModuleSafetyClass.electricalPanel,
      defaultUseMode: JobModuleUseMode.troubleshooting,
      procedureRefs: [],
      operationalStatePreconditions: ['Cooler control state known', 'CONTINUE/time delay sequence understood'],
      safetyConfirmations: ['Electrical safety', 'Rotating equipment safety', 'LOTO for fan obstruction'],
      fields: [
        BafModuleFieldSeed('coolerFan1Status', 'Cooler fan 1 status', 'enum'),
        BafModuleFieldSeed('coolerFan2Status', 'Cooler fan 2 status', 'enum'),
        BafModuleFieldSeed('overloadStatus', 'Overload status', 'enum'),
        BafModuleFieldSeed('plugCondition', 'Plug condition', 'enum'),
        BafModuleFieldSeed('timeDelaySatisfied', 'Time delay satisfied', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('MC-05-01', 'Check cooler fan plugs, starters, overloads, E-stop and time-delay condition.')],
      addAsYouGoTriggers: ['No forced cooler fans start', 'Only one fan starts'],
      closedDossierOutput: 'Cooler fan start cause, overload/motor/plug status and recovery proof.',
    ),

    BafModuleSeed(
      moduleCode: 'PC-01',
      moduleTitle: 'Post Cooling Base / Hood Interface',
      catalogueArea: 'Post Cooling',
      applicableAssetTypes: [AssetType.base, AssetType.forceCooler],
      functionalSection: 'Post-cooling equipment identity and handover',
      componentGroup: 'Post cooling base / hood / air or chilled water system',
      defaultDiscipline: JobModuleDiscipline.operations,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.futurePackage,
      procedureRefs: [],
      operationalStatePreconditions: ['Post-cooling job state known', 'Hood/base pairing recorded'],
      safetyConfirmations: ['Lifting/hot material PPE as per operation'],
      fields: [
        BafModuleFieldSeed('postCoolingBaseId', 'Post cooling base ID', 'text'),
        BafModuleFieldSeed('hoodId', 'Hood ID', 'text'),
        BafModuleFieldSeed('coolingMode', 'Cooling mode', 'enum', options: ['Air', 'Chilled water', 'Other']),
        BafModuleFieldSeed('handoverNote', 'Handover note', 'handover'),
      ],
      standardItems: [BafStandardJobItemSeed('PC-01-01', 'Record post-cooling base/hood pairing, loading/removal notes and cooling system condition.')],
      addAsYouGoTriggers: ['Post-cooling PM/handover needed', 'Future extension'],
      closedDossierOutput: 'Post-cooling equipment use, condition and history.',
    ),
    BafModuleSeed(
      moduleCode: 'AN-01',
      moduleTitle: 'Inner Cover / Convector Plate Lifting Device',
      catalogueArea: 'Ancillary Devices',
      applicableAssetTypes: [AssetType.innerCover, AssetType.base],
      functionalSection: 'Lifting-device inspection and safe handling',
      componentGroup: 'Inner cover lifter / convector plate lifting device',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.liftingRisk,
      defaultUseMode: JobModuleUseMode.preStartVerification,
      procedureRefs: ['SP-41001', 'SP-13501'],
      operationalStatePreconditions: ['Lifting device available for inspection', 'Not loaded/suspended'],
      safetyConfirmations: ['Never exceed rated load', 'Overhead-load exclusion'],
      fields: [
        BafModuleFieldSeed('deviceId', 'Device ID', 'text'),
        BafModuleFieldSeed('loadRating', 'Load rating', 'numericWithUnit'),
        BafModuleFieldSeed('crackFound', 'Crack found', 'boolean'),
        BafModuleFieldSeed('restrictedFromUse', 'Restricted from use', 'boolean'),
      ],
      standardItems: [BafStandardJobItemSeed('AN-01-01', 'Inspect lifting device ID, load rating, cracks/deformation/wear and restriction status.')],
      addAsYouGoTriggers: ['Pre-lift check', 'Scheduled lifting-device inspection', 'Post-incident verification'],
      closedDossierOutput: 'Inspection status, lift restriction and repair requirement.',
    ),
    BafModuleSeed(
      moduleCode: 'AN-02',
      moduleTitle: 'Base Maintenance Stand / Inner Cover Testing Jig',
      catalogueArea: 'Ancillary Devices',
      applicableAssetTypes: [AssetType.base, AssetType.innerCover],
      functionalSection: 'Repair/test support equipment',
      componentGroup: 'Base maintenance stand / inner cover testing jig',
      defaultDiscipline: JobModuleDiscipline.mechanical,
      defaultSafetyClass: JobModuleSafetyClass.pressureTest,
      defaultUseMode: JobModuleUseMode.postRepairVerification,
      procedureRefs: [],
      operationalStatePreconditions: ['Jig/stand selected and available', 'Load compatibility verified'],
      safetyConfirmations: ['Lifting/handling safety', 'Test pressure caution'],
      fields: [
        BafModuleFieldSeed('supportDeviceId', 'Support device ID', 'text'),
        BafModuleFieldSeed('compatibility', 'Compatibility', 'enum'),
        BafModuleFieldSeed('testPressure', 'Test pressure', 'numericWithUnit'),
        BafModuleFieldSeed('testResult', 'Test result', 'enum'),
      ],
      standardItems: [BafStandardJobItemSeed('AN-02-01', 'Record stand/jig used, compatibility, test pressure/result and defects found.')],
      addAsYouGoTriggers: ['Base/inner-cover repair testing away from normal station'],
      closedDossierOutput: 'Support equipment readiness and test outcome.',
    ),
    BafModuleSeed(
      moduleCode: 'SA-01',
      moduleTitle: 'Passive Fire Protection / CCVM / Telecom Awareness',
      catalogueArea: 'Safety / Ancillary',
      applicableAssetTypes: [AssetType.base, AssetType.furnace, AssetType.forceCooler, AssetType.innerCover],
      functionalSection: 'Support systems and incident visibility',
      componentGroup: 'Passive fire protection / CCVM / telecom',
      defaultDiscipline: JobModuleDiscipline.safety,
      defaultSafetyClass: JobModuleSafetyClass.configurationControl,
      defaultUseMode: JobModuleUseMode.futurePackage,
      procedureRefs: [],
      operationalStatePreconditions: ['Inspection/audit authorized'],
      safetyConfirmations: ['Safety-system review; not a substitute for plant emergency procedure'],
      fields: [
        BafModuleFieldSeed('systemType', 'System type', 'enum', options: ['Fire protection', 'CCVM', 'Telecom']),
        BafModuleFieldSeed('status', 'Status', 'enum'),
        BafModuleFieldSeed('defect', 'Defect', 'text'),
        BafModuleFieldSeed('escalation', 'Escalation', 'text'),
      ],
      standardItems: [BafStandardJobItemSeed('SA-01-01', 'Record safety-support system status relevant to maintenance incident or audit.')],
      addAsYouGoTriggers: ['Future safety audit', 'Incident-support workflow'],
      closedDossierOutput: 'Safety-support availability, camera/communication defects and escalation.',
    ),
  ];

  static List<BafModuleSeed> modulesForAsset(AssetType assetType) {
    final result = modules
        .where((module) => module.applicableAssetTypes.contains(assetType))
        .toList()
      ..sort((a, b) => a.moduleCode.compareTo(b.moduleCode));
    return result;
  }

  static BafModuleSeed? byCode(String moduleCode) {
    final normalized = moduleCode.trim().toUpperCase();
    for (final module in modules) {
      if (module.moduleCode.toUpperCase() == normalized) return module;
    }
    return null;
  }
}

class BafModuleSeed {
  final String moduleCode;
  final String moduleTitle;
  final String catalogueArea;
  final List<AssetType> applicableAssetTypes;
  final String functionalSection;
  final String componentGroup;
  final JobModuleDiscipline defaultDiscipline;
  final JobModuleSafetyClass defaultSafetyClass;
  final JobModuleUseMode defaultUseMode;
  final List<String> procedureRefs;
  final List<String> operationalStatePreconditions;
  final List<String> safetyConfirmations;
  final List<BafModuleFieldSeed> fields;
  final List<BafStandardJobItemSeed> standardItems;
  final List<String> addAsYouGoTriggers;
  final String closedDossierOutput;

  const BafModuleSeed({
    required this.moduleCode,
    required this.moduleTitle,
    required this.catalogueArea,
    required this.applicableAssetTypes,
    required this.functionalSection,
    required this.componentGroup,
    required this.defaultDiscipline,
    required this.defaultSafetyClass,
    required this.defaultUseMode,
    required this.procedureRefs,
    required this.operationalStatePreconditions,
    required this.safetyConfirmations,
    required this.fields,
    required this.standardItems,
    required this.addAsYouGoTriggers,
    required this.closedDossierOutput,
  });

  String get displayTitle => '$moduleCode - $moduleTitle';

  bool get requiresSafetyControl =>
      defaultDiscipline == JobModuleDiscipline.safety ||
          defaultSafetyClass != JobModuleSafetyClass.normal;

  bool get isSharedModule => defaultDiscipline == JobModuleDiscipline.shared;

  bool requiresElevatedManualAddControl({
    required bool requiredForClosure,
  }) {
    return requiresSafetyControl || isSharedModule || requiredForClosure;
  }

  String get templatePackageId => 'seed:${_slug(catalogueArea)}';
  String get templateVersionId => 'seed:${BafModuleCatalogueSeed.seedVersion}';
  String get templateModuleId => 'seed:$moduleCode';

  Map<String, dynamic> toSnapshotMap() => <String, dynamic>{
    'seedVersion': BafModuleCatalogueSeed.seedVersion,
    'source': BafModuleCatalogueSeed.sourceLabel,
    'moduleCode': moduleCode,
    'moduleTitle': moduleTitle,
    'catalogueArea': catalogueArea,
    'applicableAssetTypes': applicableAssetTypes.map((type) => type.name).toList(),
    'functionalSection': functionalSection,
    'componentGroup': componentGroup,
    'defaultDiscipline': defaultDiscipline.name,
    'defaultSafetyClass': defaultSafetyClass.name,
    'defaultUseMode': defaultUseMode.name,
    'procedureRefs': procedureRefs,
    'operationalStatePreconditions': operationalStatePreconditions,
    'safetyConfirmations': safetyConfirmations,
    'fields': fields.map((field) => field.toMap()).toList(),
    'standardItems': standardItems.map((item) => item.toMap()).toList(),
    'addAsYouGoTriggers': addAsYouGoTriggers,
    'closedDossierOutput': closedDossierOutput,
  };

  String toSnapshotJson() => jsonEncode(toSnapshotMap());

  String toFieldDefinitionsJson() => jsonEncode(
    fields.map((field) => field.toMap()).toList(),
  );

  JobModuleInstance toJobModuleInstance({
    required AssetType parentAssetType,
    required int parentAssetNumber,
    required JobModuleDiscipline discipline,
    required JobModuleUseMode useMode,
    required bool requiredForClosure,
    required bool addedDuringExecution,
    required String actorUid,
    required String actorName,
    required DateTime now,
    String? jobExecutionFirestoreId,
    int? jobExecutionLocalId,
    int? chargeNoAtEvent,
    String? templateFirestoreId,
    String? templateName,
    String? addReason,
    int displayOrder = 0,
  }) {
    final cleanReason = _cleanOptional(addReason);

    return JobModuleInstance()
      ..jobExecutionFirestoreId = _cleanOptional(jobExecutionFirestoreId)
      ..jobExecutionLocalId = jobExecutionLocalId
      ..templateFirestoreId = _cleanOptional(templateFirestoreId)
      ..templateName = _cleanOptional(templateName)
      ..templatePackageId = templatePackageId
      ..templateVersionId = templateVersionId
      ..templateModuleId = templateModuleId
      ..moduleCode = moduleCode
      ..moduleSnapshotJson = toSnapshotJson()
      ..fieldDefinitionsJson = toFieldDefinitionsJson()
      ..assetType = parentAssetType
      ..assetNumber = parentAssetNumber
      ..chargeNoAtEvent = chargeNoAtEvent
      ..moduleTitle = moduleTitle
      ..moduleDescription = closedDossierOutput
      ..status = JobModuleStatus.notStarted
      ..useMode = useMode
      ..discipline = discipline
      ..safetyClass = defaultSafetyClass
      ..isRequired = requiredForClosure
      ..requiredForClosure = requiredForClosure
      ..addedDuringExecution = addedDuringExecution
      ..displayOrder = displayOrder
      ..functionalSection = functionalSection
      ..componentGroup = componentGroup
      ..subsystem = catalogueArea
      ..procedureRefs = List<String>.from(procedureRefs)
      ..safetyConfirmations = List<String>.from(safetyConfirmations)
      ..operationalStatePreconditions =
      List<String>.from(operationalStatePreconditions)
      ..tags = <String>[
        catalogueArea,
        moduleCode,
        ...procedureRefs,
      ]
      ..responsesJson = '[]'
      ..actionsJson = '[]'
      ..addedByUid = actorUid
      ..addedByName = actorName
      ..addedAt = now
      ..addReason = cleanReason
      ..createdByUid = actorUid
      ..createdByName = actorName
      ..createdAt = now
      ..updatedByUid = actorUid
      ..updatedByName = actorName
      ..updatedAt = now
      ..metadataJson = jsonEncode(<String, dynamic>{
        'source': 'baf_module_catalogue_seed',
        'seedVersion': BafModuleCatalogueSeed.seedVersion,
        'catalogueArea': catalogueArea,
        'addAsYouGoTriggers': addAsYouGoTriggers,
        'closedDossierOutput': closedDossierOutput,
      });
  }
}

class BafModuleFieldSeed {
  final String fieldId;
  final String label;
  final String type;
  final String? unit;
  final bool required;
  final List<String> options;

  const BafModuleFieldSeed(
      this.fieldId,
      this.label,
      this.type, {
        this.unit,
        this.required = false,
        this.options = const [],
      });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'fieldId': fieldId,
    'label': label,
    'type': type,
    'unit': unit,
    'required': required,
    'options': options,
    'source': BafModuleCatalogueSeed.seedVersion,
  };
}

class BafStandardJobItemSeed {
  final String itemId;
  final String title;

  const BafStandardJobItemSeed(this.itemId, this.title);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'itemId': itemId,
    'title': title,
    'source': BafModuleCatalogueSeed.seedVersion,
  };
}

String? _cleanOptional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
