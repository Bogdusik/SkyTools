platform :ios, '13.0'

target 'SkyTools' do
  use_frameworks!

  # DJI Mobile SDK iOS
  pod 'DJI-SDK-iOS', '~> 4.16.2'
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12.0
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
      end
    end
    
    # Disable [CP] Embed Pods Frameworks script to avoid sandbox issues
    # We'll embed frameworks manually via Copy Files build phase
    installer.pods_project.targets.each do |target|
      target.build_phases.each do |phase|
        if phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && phase.name == '[CP] Embed Pods Frameworks'
          phase.shell_script = "echo 'Framework embedding disabled due to sandbox restrictions'\n"
        end
      end
    end
  end
end
