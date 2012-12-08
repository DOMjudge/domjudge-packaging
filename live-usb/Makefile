EXTRA = extra-files.tgz

default: $(EXTRA)

$(EXTRA): FORCE
	rm -f $(EXTRA)
	cd files && tar czf ../$(EXTRA) .

FORCE:

.PHONY: FORCE
