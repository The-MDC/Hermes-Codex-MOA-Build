---
name: mdolab-dafoam
description: """"
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---


# mdolab/dafoam Integration for Hermes Agent

## Overview
This skill integrates the **mdolab/dafoam** into Hermes Agent, providing access to DAFoam: Discrete Adjoint with OpenFOAM for High-fidelity Multidisciplinary Design Optimization (MDO).

## Why DAFoam?
- **Discrete adjoint method** — efficient gradient computation for MDO
- **OpenFOAM integration** — popular open-source CFD platform
- **OpenMDAO coupling** — multidisciplinary design optimization framework
- **High-fidelity analysis** — competitive speed, scalability, and accuracy
- **Python interface** — convenient coupling with design workflows

## Why Hermes Integration?
- Automate design optimization workflows
- Generate optimization reports via natural language
- Integrate with agent swarm for parallel optimization
- Enable closed-loop design with agent-driven iteration

## Prerequisites

### System Requirements
- **OpenFOAM** — version 10+ recommended
  ```bash
  # Ubuntu example
  sudo add-apt-repository ppa:openfoam/official
  sudo apt-get update
  sudo apt-get install openfoam10
  ```
- **OpenMDAO** — version 3.25+
  ```bash
  pip install openmdao
  ```
- **Python 3.8+**
- **Hermes Agent v1.0+**

### Optional Dependencies
- **SciPy** — for additional numerical routines
- **NumPy** — array operations
- **Matplotlib** — result visualization

## Installation

```bash
# Install Python dependencies
pip install openmdao scipy numpy matplotlib

# Verify OpenFOAM installation
source $FOAM_ROOT/etc/bashrc  # OpenFOAM setup script
echo $WM_PROJECT_VERSION  # Should print version

# Install dafoam package
pip install dafoam

# Verify installation
dafoam --version

# Or from source
git clone https://github.com/mdolab/dafoam.git
cd dafoam
pip install -e .
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  mdolab-dafoam: true

# Environment variables
export OPENFOAM_ROOT="/opt/openfoam10"  # or your OpenFOAM installation path
export OPENMDAO_DEFAULT_PLUGINS=statsd  # optional
export DAFOAM_LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR
export HERMES_DAFOAM_WORKDIR="$HOME/.hermes/work/dafoam"
```

## Usage

### Basic DAFoam Workflow

```python
from hermes_tools import dafoam

# Initialize optimization problem
problem = dafoam.Problem()

# Define design variables
problem.add_design_var("angle_of_attack", lower=0, upper=15)

# Define objectives
problem.add_objective("lift_to_drag_ratio")

# Add constraints
problem.add_constraint("drag", upper=100)

# Set up OpenMDAO problem
problem.setup()

# Run optimization
results = problem.run()

# Output results
print(f"Optimal angle of attack: {results['design_vars']['angle_of_attack']}")
print(f"Optimal L/D ratio: {results['objectives']['lift_to_drag_ratio']}")
```

### OpenMDAO + OpenFOAM Coupling

```bash
# Run a coupled optimization
python src/examples/python_examples/smoke_example01.py

# Or via Hermes agent
hermes ask "Run aerodynamic optimization on NACA 0012 airfoil"

# Custom optimization workflow
from hermes_tools import dafoam

# 1. Define geometry
geometry = dafoam.Geometry.from_naca(0012)

# 2. Set up flow conditions
flow = dafoam.Flow(
    alpha=5.0,      # angle of attack
    mach=0.15,      # Mach number
    re=3e6          # Reynolds number
)

# 3. Discrete adjoint analysis
adjoint = dafoom.adjoint(geometry, flow)

# 4. Compute gradients
gradients = adjoint.compute_gradients("lift", ["angle_of_attack"])

# 5. Run optimization loop
# (integrate with your preferred optimizer)
```

### Hermes Agent Commands

```bash
# Start DAFoam workflow
hermes dafoam --start --geometry naca0012 --objective "lift_drag_ratio"

# Check optimization status
hermes dafoam --status

# Retrieve results
hermes dafoam --results

# Run parallel optimizations across MOA1 tiers
hermes moa1 --run dafoam --geometry naca0012 --parallel
```

### Benefits
- **High-fidelity MDO** — discrete adjoint with OpenFOAM
- **Agent-swarm optimization** — parallelize across MOA1 tiers
- **Natural language interface** — Hermes agent controls DAFoam
- **Closed-loop design** — agent-driven iteration on designs
- **Python-first** — easy integration with existing workflows

## Verification

```bash
# Check Hermes recognizes dafoam
hermes doctor

# Test basic workflow
hermes ask "Set up simple aerodynamic optimization"

# Verify OpenFOAM access
hermes ask "Check OpenFOAM installation"

# Run test case
hermes ask "Run smoke example from OpenMDAO dafoam examples"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| dafoam not found | Ensure OpenFOAM is installed and sourced |
| OpenMDAO import errors | Reinstall: `pip install --upgrade openmdao` |
| Optimization doesn't converge | Check design variable bounds |
| Memory errors | Reduce problem size or increase heap |
| Parallel failures | Check OpenFOAM MPI configuration |
| Geometry import errors | Verify NACA airfoil format |

## References
- Original repo: https://github.com/mdolab/dafoam
- Docs: https://dafoam.github.io
- License: MIT
- OpenFOAM: https://www.openfoam.com/
- OpenMDAO: https://openmdao.org/
- Citation: DAFoam paper at https://doi.org/10.1016/j.jcp.2019.108531