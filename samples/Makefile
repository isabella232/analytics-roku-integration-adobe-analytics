#
#  Copyright (c) 2015 Roku, Inc. All rights reserved.
#  Simple Makefile for Roku Channel Development
#

APPNAME = hello-segment
IMPORTS = 

APPSROOT = .
include $(APPSROOT)/app.mk

.PHONY: install-app
install-app: segment-config install

.PHONY: clean-lib
clean-lib: clean
	cp ../source/analytics/SegmentAdobeIntegration.brs "./source/library/Segment SDK"
	grep -v analytics_write_key manifest > manifest.tmp
	mv manifest.tmp manifest

.PHONY: segment-config
segment-config: clean-lib
	cp ../source/analytics/SegmentAdobeIntegration.brs "./source/library/Segment SDK"
	@if ! grep -q "analytics_write_key" manifest ; then echo "analytics_write_key=$(SEGMENT_WRITE_KEY)" >> manifest ; fi

