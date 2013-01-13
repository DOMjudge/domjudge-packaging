EXTRA = extra-files.tgz

default: $(EXTRA)

$(EXTRA): FORCE
	rm -f $(EXTRA)
	cd files && chmod 1777 tmp && tar czf ../$(EXTRA) .

FORCE:

.PHONY: FORCE
