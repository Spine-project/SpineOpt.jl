# SpineModel.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://spine-project.github.io/Spine-Model/latest/index.html)

A julia Module to generate, run, and develop energy system integration models using the Spine framework.
See [Spine](http://www.spine-model.org/) for more information.

## Getting started

### Pre-requisites

- [julia 1.0](https://julialang.org/)
- [PyCall](https://github.com/JuliaPy/PyCall.jl)
- [JuMP](https://github.com/JuliaOpt/JuMP.jl)
- [JSON](https://github.com/JuliaIO/JSON.jl)
- [Clp](https://github.com/JuliaOpt/Clp.jl)
- [DataFrames](https://github.com/JuliaData/DataFrames.jl)
- [spinedatabase_api](https://github.com/Spine-project/Spine-Database-API)

### Installation

From the Julia REPL, press the key `]` to enter the Pkg-REPL mode, then run

```julia
(v1.0) pkg> add https://github.com/Spine-project/Spine-Model.git#dev
```

This will install `SpineModel.jl` and all its dependencies, except for `spinedatabase_api` which is
a Python package and thus needs to be installed separately.

#### Installing spinedatabase_api

If you have already installed `spinedatabase_api` to use it in [Spine Toolbox](https://github.com/Spine-project/Spine-toolbox), you can also use it in Spine Model.
All you need to do is configure PyCall to use the same python as Spine Toolbox. In the julia REPL, run

```julia
using PyCall
ENV["PYTHON"] = "... path of the python program you want ..."
Pkg.build("PyCall")
```

and restart julia afterwards.

If you haven't installed `spinedatabase_api` yet or don't want to reconfigure PyCall, then you need to do the following:

1. Find out the path of the python program used by PyCall. In the julia REPL, run

   ```julia
   using PyCall
   PyCall.pyprogramname
   ```
2. Install `spinedatabase_api` in that python. Open a terminal (e.g. command prompt
   on Windows) and run

   ```
   python -m pip install git+https://github.com/Spine-project/Spine-Database-API.git
   ```

   where `python` is the path returned by `PyCall.pyprogramname`.

### Upgrading

To upgrade to the most recent version, enter the Pkg-REPL mode and run

```julia
(v1.0) pkg> up SpineModel
```

### Usage

In julia, run

```
using SpineModel
```

## Reporting Issues and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Spine Model is licensed under GNU Lesser General Public License version 3.0 or later.
