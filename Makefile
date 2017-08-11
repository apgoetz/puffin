include config.mk

AWKLIB = ${PREFIX}/lib/puffin

FILES=puffin

LIBS=render.awk config.awk make_depend.awk puffin.ini lib.awk templater.awk rules.awk

all: 
	@echo Compiling puffin executable
	@sed "s#PUFLIB_PATH#${AWKLIB}#g" < bin/puffin.template > bin/puffin
	@chmod 755 bin/puffin
	@echo Compiled

install: all
	@echo Installing puffin executables to ${PREFIX}/bin
	@mkdir -p ${PREFIX}/bin
	@cp $(patsubst %, bin/%, ${FILES}) ${PREFIX}/bin
	@echo Installing awk lib files to ${AWKLIB}
	@mkdir -p ${AWKLIB}
	@cp $(patsubst %, lib/%, ${LIBS}) ${AWKLIB}
	@echo Installation Complete

uninstall:
	@echo Uninstalling puffin executables
	@rm $(patsubst %, ${PREFIX}/bin/%, ${FILES}) 
	@echo Uninstalling awk lib files
	@rm -rf ${AWKLIB}
	@echo Uninstallation Complete

clean:
	@rm bin/puffin
