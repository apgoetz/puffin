include config.mk
FILES=puffin puffin-render puffin-configure
LIBS=render.awk config.awk

all: 
	@echo Compiling puffin executable
	@sed "s#ZODLIB_PATH#${AWKLIB}#g" < bin/puffin.template > bin/puffin
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
