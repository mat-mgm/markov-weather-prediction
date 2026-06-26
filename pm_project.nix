let
  nixpkgs-src = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/refs/tags/25.05.tar.gz";
  };

  pkgs = import nixpkgs-src {
    config = {
      # allowUnfree may be necessary for some packages, but in general you should not need it.
      allowUnfree = false;
    };
  };

  # This is the Python version that will be used.
  pythonVersion = pkgs.python313;

  pythonWithPkgs = pythonVersion.withPackages (pythonPkgs: with pythonPkgs; [
    # This list contains tools for Python development.
    # You can also add other tools, like black.
    #
    # Note that even if you add Python packages here like PyTorch or Tensorflow,
    # they will be reinstalled when running `pip -r requirements.txt` because
    # virtualenv is used below in the shellHook.
    ipython
    pip
    setuptools
    virtualenvwrapper
    wheel

    # Machine learning packages
    jupyter
  ]);

  lib-path = with pkgs; lib.makeLibraryPath [
    libffi
    openssl
    stdenv.cc.cc
    # If you want to use CUDA, you should uncomment this line.
    #linuxPackages.nvidia_x11
  ];

  shell = pkgs.mkShell {
    buildInputs = [
      # my python and packages
      pythonWithPkgs
      # Auxiliary packages needed for the jupyter's notebooks
      pkgs.graphviz
      # other packages needed for compiling python libs
      pkgs.readline
      pkgs.libffi
      pkgs.openssl
      # unfortunately needed because of messing with LD_LIBRARY_PATH below
      pkgs.git
      pkgs.openssh
      pkgs.rsync
    ];

    shellHook = ''
      # Allow the use of wheels.
      SOURCE_DATE_EPOCH=$(date +%s)

      # Augment the dynamic linker path
      export "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib-path}"

      # Setup the virtual environment if it doesn't already exist.
      VENV=.venv
      if test ! -d $VENV; then
        virtualenv $VENV
      fi
      source ./$VENV/bin/activate
      export PYTHONPATH=`pwd`/$VENV/${pythonVersion.sitePackages}/:$PYTHONPATH

      # Set comfy aliases
      alias \
        q="exit" \
        cl="clear" \
        nv="nvim"

      # Upgrade pip
      pip install --upgrade pip

      pip install numpy pandas matplotlib seaborn
      pip install kagglehub graphviz
      #scipy scikit-learn

      # Run jupyter notebook server
      jupyter notebook &
    '';
  };
in
shell
