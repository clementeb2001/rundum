"""Generate the dependency-free Xcode project. Run from any directory with Python 3."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
objects = {}
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def add(key_name, isa, **kwargs):
    key = uid(key_name)
    objects[key] = dict(isa=isa, **kwargs)
    return key
def quote(value): return json.dumps(str(value))
def serialize(value):
    if isinstance(value, dict): return '{ ' + ' '.join(f'{quote(k)} = {serialize(v)};' for k, v in value.items()) + ' }'
    if isinstance(value, list): return '(' + ', '.join(serialize(v) for v in value) + ')'
    return quote(value)

project_id = uid('project')
config_file = add('config', 'PBXFileReference', lastKnownFileType='text.xcconfig', path='Config/App.xcconfig', sourceTree='<group>')
storekit_file = add('storekit', 'PBXFileReference', lastKnownFileType='text', path='Config/Rundum.storekit', sourceTree='<group>')
children = [config_file, storekit_file]
products = []
targets = []
for name, folder, bundle, plist, entitlement in [
    ('Rundum', 'App', 'app.rundum.ios', 'Config/Info.plist', 'Config/App.entitlements'),
    ('RundumWidget', 'Widget', 'app.rundum.ios.widget', 'Config/Widget-Info.plist', 'Config/Widget.entitlements')]:
    source_paths = sorted((root / folder).glob('*.swift'))
    if name == 'Rundum': source_paths += sorted((root / 'Core').glob('*.swift'))
    builds = []
    for path in source_paths:
        rel = str(path.relative_to(root))
        file = add(rel, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=rel, sourceTree='<group>')
        children.append(file)
        builds.append(add(rel+'build', 'PBXBuildFile', fileRef=file))
    sources = add(name+'sources', 'PBXSourcesBuildPhase', buildActionMask='2147483647', files=builds, runOnlyForDeploymentPostprocessing='0')
    resource_builds = []
    if name == 'Rundum':
        assets = add('assets', 'PBXFileReference', lastKnownFileType='folder.assetcatalog', path='App/Resources/Assets.xcassets', sourceTree='<group>')
        children.append(assets)
        resource_builds.append(add('assetsbuild', 'PBXBuildFile', fileRef=assets))
        variants = []
        for lang in ['de', 'fr', 'en']:
            variants.append(add(lang, 'PBXFileReference', lastKnownFileType='text.plist.strings', name=lang, path=f'App/Resources/{lang}.lproj/InfoPlist.strings', sourceTree='<group>'))
        group = add('localization', 'PBXVariantGroup', children=variants, name='InfoPlist.strings', sourceTree='<group>')
        children.append(group)
        resource_builds.append(add('localizationbuild', 'PBXBuildFile', fileRef=group))
    privacy = add(name+'privacy', 'PBXFileReference', lastKnownFileType='text.xml', path='App/Resources/PrivacyInfo.xcprivacy', sourceTree='<group>')
    children.append(privacy)
    resource_builds.append(add(name+'privacybuild', 'PBXBuildFile', fileRef=privacy))
    resources = add(name+'resources', 'PBXResourcesBuildPhase', buildActionMask='2147483647', files=resource_builds, runOnlyForDeploymentPostprocessing='0')
    suffix = 'app' if name == 'Rundum' else 'appex'
    product = add(name+'product', 'PBXFileReference', explicitFileType='wrapper.application' if name == 'Rundum' else 'wrapper.app-extension', path=name+'.'+suffix, sourceTree='BUILT_PRODUCTS_DIR', includeInIndex='0')
    products.append(product)
    configs = []
    for mode in ['Debug', 'Release']:
        settings = {'PRODUCT_NAME': name, 'PRODUCT_BUNDLE_IDENTIFIER': bundle, 'INFOPLIST_FILE': plist, 'CODE_SIGN_ENTITLEMENTS': entitlement, 'CODE_SIGN_STYLE': 'Automatic', 'SDKROOT': 'iphoneos', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O', 'SWIFT_EMIT_LOC_STRINGS': 'YES', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'], 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'}
        if name == 'Rundum': settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
        settings['PRODUCT_BUNDLE_IDENTIFIER'] = '$(APP_BUNDLE_ID)' if name == 'Rundum' else '$(WIDGET_BUNDLE_ID)'
        if name != 'Rundum': settings.update(APPLICATION_EXTENSION_API_ONLY='YES', SKIP_INSTALL='YES', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'])
        configs.append(add(name+mode, 'XCBuildConfiguration', baseConfigurationReference=config_file, buildSettings=settings, name=mode))
    configuration_list = add(name+'configs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
    targets.append(add(name+'target', 'PBXNativeTarget', name=name, productName=name, productReference=product, productType='com.apple.product-type.application' if name == 'Rundum' else 'com.apple.product-type.app-extension', buildConfigurationList=configuration_list, buildPhases=[sources, resources], buildRules=[], dependencies=[]))

proxy = add('widgetproxy', 'PBXContainerItemProxy', containerPortal=project_id, proxyType='1', remoteGlobalIDString=targets[1], remoteInfo='RundumWidget')
dep = add('widgetdependency', 'PBXTargetDependency', target=targets[1], targetProxy=proxy)
embed_file = add('embedwidgetfile', 'PBXBuildFile', fileRef=products[1], settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
embed = add('embedwidget', 'PBXCopyFilesBuildPhase', buildActionMask='2147483647', dstPath='', dstSubfolderSpec='13', files=[embed_file], name='Embed App Extensions', runOnlyForDeploymentPostprocessing='0')
objects[targets[0]]['buildPhases'].append(embed)
objects[targets[0]]['dependencies'].append(dep)
products_group = add('products', 'PBXGroup', children=products, name='Products', sourceTree='<group>')
main = add('main', 'PBXGroup', children=children+[products_group], sourceTree='<group>')
configs = [add('project'+mode, 'XCBuildConfiguration', buildSettings={'CLANG_ENABLE_MODULES': 'YES', 'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '16.0'}, name=mode) for mode in ['Debug', 'Release']]
configlist = add('projectconfigs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
add('project', 'PBXProject', attributes={'LastUpgradeCheck': '1600', 'BuildIndependentTargetsInParallel': 'YES'}, buildConfigurationList=configlist, compatibilityVersion='Xcode 14.0', developmentRegion='de', hasScannedForEncodings='0', knownRegions=['de', 'en', 'fr', 'Base'], mainGroup=main, productRefGroup=products_group, projectDirPath='', projectRoot='', targets=targets)
project = root / 'Rundum.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion': '1', 'classes': {}, 'objectVersion': '56', 'objects': objects, 'rootObject': project_id})+'\n')
schemes = project / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes/'Rundum.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[0]}" BuildableName="Rundum.app" BlueprintName="Rundum" ReferencedContainer="container:Rundum.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[0]}" BuildableName="Rundum.app" BlueprintName="Rundum" ReferencedContainer="container:Rundum.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <TestAction buildConfiguration="Debug"/><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
scheme_path = schemes / 'Rundum.xcscheme'
scheme_path.write_text(scheme_path.read_text().replace('</LaunchAction>', '<StoreKitConfigurationFileReference identifier="../../Config/Rundum.storekit"/></LaunchAction>'))
(schemes/'Rundum Device.xcscheme').write_text(scheme_path.read_text().replace('<StoreKitConfigurationFileReference identifier="../../Config/Rundum.storekit"/>', ''))
print(project)
