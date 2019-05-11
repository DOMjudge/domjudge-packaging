EXTRA = extra-files.tgz

default: $(EXTRA)

$(EXTRA): FORCE
	rm -f $(EXTRA)
	cd files && chmod 1777 tmp && tar cz --owner=root --group=root -f ../$(EXTRA) .

FORCE:

.PHONY: FORCE
