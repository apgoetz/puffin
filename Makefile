include config.mk
FILES=awkweb awkweb-render awkweb-configure
LIBS=render.awk config.awk

all: 
	@echo Compiling awkweb executable
	@sed "s#ZODLIB_PATH#${AWKLIB}#g" < bin/awkweb.template > bin/awkweb
	@chmod 755 bin/awkweb
	@echo Compiled

install: all
	@echo Installing awkweb executables to ${PREFIX}/bin
	@mkdir -p ${PREFIX}/bin
	@cp $(patsubst %, bin/%, ${FILES}) ${PREFIX}/bin
	@echo Installing awk lib files to ${AWKLIB}
	@mkdir -p ${AWKLIB}
	@cp $(patsubst %, lib/%, ${LIBS}) ${AWKLIB}
	@echo Installation Complete

uninstall:
	@echo Uninstalling awkweb executables
	@rm $(patsubst %, ${PREFIX}/bin/%, ${FILES}) 
	@echo Uninstalling awk lib files
	@rm -rf ${AWKLIB}
	@echo Uninstallation Complete

clean:
	@rm bin/awkweb
