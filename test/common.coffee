assert = require 'assert'
onvif = require('../lib/onvif')
serverMockup = require('./serverMockup')

describe 'Simple and common get functions', () ->
  cam = null
  before (done) ->
    options = {
      hostname: process.env.HOSTNAME || 'localhost'
      username: 'admin'
      password: '9999'
      port: if process.env.PORT then parseInt(process.env.PORT) else 10101
    }
    cam = new onvif.Cam options, done

  describe 'discover', () ->
    this.timeout 10000
    it 'should discover at least one device (mockup server)', (done) ->
      onvif.Discovery.probe {timeout: 1000}, (err, cams) ->
        assert.equal err, null
        assert.ok cams.length > 0
        assert.ok cams[0] instanceof onvif.Cam
        done()
    it 'should discover at least one device with defaults and callback', (done) ->
      onvif.Discovery.probe (err, cams) ->
        assert.equal err, null
        assert.ok cams.length > 0
        assert.ok cams[0] instanceof onvif.Cam
        done()
    it 'should work as event emitter (also test `probe` without params)', (done) ->
      onvif.Discovery.once 'device', (cam) ->
        assert.ok cam
        assert.ok cam instanceof onvif.Cam
        done()
      onvif.Discovery.probe()
    it 'should return info object instead of Cam object when `resolve` is false', (done) ->
      onvif.Discovery.once 'device', (cam) ->
        assert.ok cam
        assert.equal cam instanceof onvif.Cam, false
        done()
      onvif.Discovery.probe {resolve: false}

  describe '_request', () ->
    it 'brokes when no arguments are passed', (done) ->
      assert.throws () -> cam._request()
      done()
    it 'brokes when no callback is passed', (done) ->
      assert.throws () -> cam._request({})
      done()
    it 'brokes when no options.body is passed', (done) ->
      assert.throws () -> cam._request({}, () -> {})
      done()
    it 'should return an error message when request is bad', (done) ->
      cam._request {body: 'test'}, (err) ->
        assert.notEqual err, null
        done()
    it 'should return an error message when the network is unreachible', (done) ->
      host = cam.hostname
      cam.hostname = 'wrong hostname'
      cam._request {body: 'test'}, (err) ->
        assert.notEqual err, null
        cam.hostname = host
        done()
    it 'should work nice with the proper request body', (done) ->
      cam._request {body: '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">' +
        '<s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">' +
        '<GetSystemDateAndTime xmlns="http://www.onvif.org/ver10/device/wsdl"/>' +
        '</s:Body>' +
        '</s:Envelope>'}
      , (err) ->
        assert.equal err, null
        done()
    it 'should handle SOAP Fault as an error (http://www.onvif.org/onvif/ver10/tc/onvif_core_ver10.pdf, pp.45-46)', (done) ->
      cam._request {body: '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">' +
          '<s:Body xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">' +
          '<UnknownCommand xmlns="http://www.onvif.org/ver10/device/wsdl"/>' +
          '</s:Body>' +
          '</s:Envelope>'}
      , (err) ->
        assert.notEqual err, null
        assert.ok err instanceof Error
        done()

  describe 'connect', () ->
    it 'should connect to the cam, fill startup properties', (done) ->
      cam.connect (err) ->
        assert.equal err, null
        assert.ok cam.capabilities
        assert.ok cam.uri.ptz
        assert.ok cam.uri.media
        assert.ok cam.videoSources
        assert.ok cam.profiles
        assert.ok cam.defaultProfile
        assert.ok cam.activeSource
        done()
    it 'should return an error when upstart is unfinished', (done) ->
      cam.getCapabilities = (cb) ->
        cb new Error('error')
      cam.connect (err) ->
        assert.notEqual err, null
        delete cam.getCapabilities
        done()

  describe 'getSystemDateAndTime', () ->
    it 'should return valid date', (done) ->
      cam.getSystemDateAndTime (err, data) ->
        assert.equal err, null
        assert.ok (data instanceof Date)
        done()

  describe 'getCapabilities', () ->
    it 'should return a capabilities object with correspondent properties and also set them into #capability property', (done) ->
      cam.getCapabilities (err, data) ->
        assert.equal err, null
        assert.ok cam.profiles.every (profile) ->
          ['name', 'videoSourceConfiguration', 'videoEncoderConfiguration', 'PTZConfiguration'].every (prop) ->
            profile[prop]
        assert.equal cam.capabilities, data
        done()
    it 'should store PTZ link in ptzUri property', (done) ->
      assert.equal cam.uri.ptz.href, cam.capabilities.PTZ.XAddr
      done()
    it 'should store uri links for extensions', (done) ->
      assert.ok Object.keys(cam.capabilities.extension).every (ext) -> cam.uri[ext]
      done()

  describe 'getServiceCapabilities', () ->
    it 'should return a service capabilities object and also set them into #serviceCapabilities property', (done) ->
      cam.getServiceCapabilities (err, data) ->
        assert.equal err, null
        assert.ok ['network', 'security', 'system', 'auxiliaryCommands'].every (prop) ->
          data[prop]
        assert.equal cam.serviceCapabilities, data
        done()

  describe 'getVideoSources', () ->
    it 'should return a videosources object with correspondent properties and also set them into videoSources property', (done) ->
      cam.getVideoSources (err, data) ->
        assert.equal err, null
        assert.ok ['$', 'framerate', 'resolution'].every (prop) ->
          data[prop] != undefined
        assert.equal cam.videoSources, data
        done()

  describe 'getProfiles', () ->
    it 'should create an array of profile objects with correspondent properties', (done) ->
      cam.getProfiles (err, data) ->
        assert.equal err, null
        assert.ok Object.keys(cam.profiles).length > 0
        assert.equal cam.profiles, data
        done()

  describe 'gotoPreset', () ->
    it 'should just run', (done) ->
      cam.gotoPreset {preset: Object.keys(cam.profiles)[0]}, (err, data) ->
        assert.equal err, null
        done()

  describe 'getServices', () ->
    it 'should return an array of services objects', (done) ->
      cam.getServices (err, data) ->
        assert.equal err, null
        assert.ok Array.isArray data
        assert.ok data.every (service) ->
          service.namespace and service.XAddr and service.version
        done()

  describe 'getDeviceInformation', () ->
    it 'should return an information about device', (done) ->
      cam.getDeviceInformation (err, data) ->
        assert.equal err, null
        assert.ok ['manufacturer', 'model', 'firmwareVersion', 'serialNumber', 'hardwareId'].every (prop) ->
          data[prop] != undefined
        console.log 'Device Information:'
        console.log data
        assert.equal cam.deviceInformation, data
        done()

  describe 'getStreamUri', () ->
    it 'should return a media stream uri', (done) ->
      cam.getStreamUri {protocol: 'HTTP'}, (err, data) ->
        assert.equal err, null
        assert.ok ['uri', 'invalidAfterConnect', 'invalidAfterReboot', 'timeout'].every (prop) ->
          data[prop] != undefined
        done()
    it 'should return a default media stream uri with no options passed', (done) ->
      cam.getStreamUri (err, data) ->
        assert.equal err, null
        assert.ok ['uri', 'invalidAfterConnect', 'invalidAfterReboot', 'timeout'].every (prop) ->
          data[prop] != undefined
        done()

  describe 'getSnapshotUri', () ->
    it 'should return a default media uri with no options passed', (done) ->
      cam.getSnapshotUri (err, data) ->
        assert.equal err, null
        assert.ok ['uri', 'invalidAfterConnect', 'invalidAfterReboot', 'timeout'].every (prop) ->
          data[prop] != undefined
        done()

  describe 'getPresets', () ->
    it 'should return array of preset objects and sets them to #presets', (done) ->
      cam.getPresets {}, (err, data) ->
        assert.equal err, null
        assert.ok Object.keys(data).every (presetName) ->
          typeof data[presetName] == 'string'
        assert.equal cam.presets, data
        done()

  describe 'getNodes', () ->
    it 'should return object of nodes and sets them to #nodes', (done) ->
      cam.getNodes (err, data) ->
        assert.equal err, null
        assert.ok typeof data == 'object'
        assert.deepEqual cam.nodes, data
        done()

  describe 'getConfigurations', () ->
    it 'should return object of configurations and sets them to #configurations', (done) ->
      cam.getConfigurations (err, data) ->
        assert.equal err, null
        assert.ok typeof data == 'object'
        assert.deepEqual cam.configurations, data
        done()

  describe 'getConfigurationOptions', () ->
    it 'should return an options object for every configuation token', (done) ->
      tokens = Object.keys cam.configurations
      cou = tokens.length
      tokens.forEach (token) ->
        cam.getConfigurationOptions token, (err, data) ->
          assert.equal err, null
          assert.ok typeof data == 'object'
          done() if not (--cou)

  describe 'absolute move', () ->
    it 'should returns empty RelativeResponseObject', (done) ->
      cam.absoluteMove {
        x: 1
        y: 1
        zoom: 1
      }, done
    it 'should works without callback', () ->
      cam.absoluteMove {
        x: 0
        y: 0
        zoom: 1
      }

  describe 'relative move', () ->
    it 'should returns empty RelativeResponseObject', (done) ->
      cam.relativeMove {
        speed: {
          x: 0.1
          y: 0.1
        }
        x: 1
        y: 1
        zoom: 1
      }, done
    it 'should works without callback', () ->
      cam.relativeMove {
        speed: {
          x: 0.1
          y: 0.1
        }
        x: 1
        y: 1
        zoom: 1
      }

  describe 'continuous move', () ->
    it 'should returns empty ContinuousResponseObject', (done) ->
      cam.continuousMove {
        x: 0.1
        y: 0.1
        zoom: 0
      }, done
    it 'should set ommited pan-tilt parameters to zero', (done) ->
      cam.continuousMove {
        x: 0.1
        zoom: 0
      }, done

  describe 'stop', () ->
    it 'should stop all movements when options are ommited', (done) ->
      cam.stop done
    it 'should stop only zoom movement', (done) ->
      cam.stop {zoom: true}, done
    it 'should stop only pan-tilt movement', (done) ->
      cam.stop {panTilt: true}, done
    it 'should stop all movements', (done) ->
      cam.stop {zoom: true, panTilt: true}, done
    it 'should work without callback', (done) ->
      cam.stop {}
      cam.stop()
      done()

  describe 'getStatus', () ->
    it 'should returns position status', (done) ->
      cam.getStatus {}, (err, data) ->
        assert.equal err, null
        done()

  describe 'systemReboot', () ->
    it 'should return a server message', (done) ->
      cam.systemReboot (err, data) ->
        assert.equal err, null
        assert.equal typeof data, 'string'
        done()
