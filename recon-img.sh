#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# :set number tabstop=2 shiftwidth=2 fileformat=unix expandtab
# 
# DESCRIPTION:
#   Command line wrapper script for SVRTK's reconstruct super-resolution executable.
#   This current implementation is designed to be automated - however, this requires 
#   FSL - a suite of image analysis tools that are only installable on UNIX systems.
# 
# NOTE:
#   This command line wrapper are best suited for the LSF at CCHMC's HPC.
# 


#######################################
# Prints usage to the command line interface.
# Arguments:
#   None
#######################################
Usage() {
  cat << USAGE

  Usage: $(basename ${0}) <required arguments> [optional arguments]

  Command line wrapper script intended for use with SVRTK's image super-resolution
  reconstruction executable. Designed to run on the UNIX command line.

  SVRTK can downloaded and compiled from here: https://github.com/SVRTK/SVRTK

  The required dependencies include:
    * SVRTK (mirtk reconstruct)
    * Python v2+
    * FSL

  Required Arguments

    -i, --img-dir     DIR     Input image directory of NIFTI files
    -o, --out         FILE    Output image name and directory path (must end with '.nii.gz')
    -r, --resolution  FLOAT   Output image isotropic image resolution (in mm)

  Optional Arguments

    -g, --glob-str    STR     Input image directory glob-string to select specific image contrast/modality
    --iterations      INT     Number of iterations for image reconstruction/super-resolution [default: 3]
    --no-cleanup              DO NOT perform clean-up [default: FALSE]
    -h, -help, --help         Prints usage to the command line
  
  Usage: $(basename ${0}) -i <DIR> -o <FILE> -r <FLOAT> [optional arguments]

  NOTE: Output image path MUST be absolute.

USAGE
  exit 1
}


#######################################
# Prints message to the command line interface
#   in some arbitrary color.
# Arguments:
#   msg
#######################################
echo_color(){
  msg='\033[0;'"${@}"'\033[0m'
  echo -e ${msg} 
}


#######################################
# Prints message to the command line interface
#   in red.
# Arguments:
#   msg
#######################################
echo_red(){
  echo_color '31m'"${@}"
}


#######################################
# Prints message to the command line interface
#   in green.
# Arguments:
#   msg
#######################################
echo_green(){
  echo_color '32m'"${@}"
}


#######################################
# Prints message to the command line interface
#   in blue.
# Arguments:
#   msg
#######################################
echo_blue(){
  echo_color '36m'"${@}"
}


#######################################
# Prints message to the command line interface
#   in red when an error is intened to be raised.
# Arguments:
#   msg
#######################################
exit_error(){
  echo_red "${@}"
  exit 1
}


#######################################
# Logs the command to file, and executes (runs) the command.
# Globals:
#   log
#   err
# Arguments:
#   Command to be logged and performed.
#######################################
run(){
  echo "${@}"
  "${@}" >>${log} 2>>${err}
  if [[ ! ${?} -eq 0 ]]; then
    echo "failed: see log files ${log} ${err} for details"
    exit 1
  fi
  echo "-----------------------"
}


#######################################
# Performs dependency check to ensure
#   that the command is in the system
#   PATH variable.
# Arguments:
#   Command to be checked
#######################################
dependency_check(){
  cmd=${1}

  # Check dependency
  if ! hash ${cmd} 2>/dev/null; then
    exit_error "Dependenncy: ${cmd} is not installed or added to the system path. Please check. Exiting..."
  fi
}


#######################################
# Realpath substitute function if it is
#   not installed natively on UNIX system.
# 
# NOTE: 
#   * This function is conditionally 
#     defined - i.e. this function is only
#     defined if and only if the 'realpath'
#     UNIX executable is not installed.
#   * Python v2+ is REQUIRED.
# 
# WARNING: This function does not resolve 
#   symlinks.
# 
# Arguments:
#   File or directory for real path.
#######################################
if ! hash realpath 2>/dev/null; then
  dependency_check python
  realpath () { $(python -c "from os.path import abspath; print(abspath('${1}'))") ; }
fi


#######################################
# Thresholds and binarizes an MR image
#   to create an image mask.
# Arguments:
#   -i, --img     Input image.
#   -o, --out     Image output name.
#   -t, --thresh  Values below this percentage are thresholded to 0. [optional]
#######################################
binarize_mri(){
  # Set defaults
  local thresh=15

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      -i|--img) shift; local img=${1} ;;
      -o|--out) shift; local out=${1} ;;
      -t|--thresh) shift; local thresh=${1} ;;
      -*) echo_red "binarize_mri: Unrecognized option ${1}" >&2; ;;
      *) break ;;
    esac
    shift
  done

  # Binarize and threshold image
  fslmaths ${img} -thrP ${thresh} -bin ${out}
}


#######################################
# Selects the image with the most coverage
#   of the brain (i.e. most number of voxels).
# NOTE: Command line flags must be placed
#   before the rest of the arguments.
# Arguments:
#   t, --tmp-dir  Temporary directory to use. [Optional]
#   -no-cleanup   Do not perform clean-up. [Optional]
#######################################
select_best_img(){
  # Set defaults
  local cwd=$(pwd)
  local tmpdir=${cwd}/tmp${RANDOM}
  local cleanup="true"
  local min=1000000   # This number needs to be VERY LARGE for the initial value comparison

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      -t|--tmp-dir) shift; local tmpdir=${1} ;;
      --no-cleanup) local cleanup="false" ;;
      -*) echo_red "select_best_img: Unrecognized option ${1}" >&2; ;;
      *) break ;;
    esac
    shift
  done

  local _string="${@}"
  local IFS=' ' 
  read -a _arr <<< "${_string}"
  unset IFS

  # Create temporary directory
  if [[ ! -d ${tmpdir} ]]; then
    mkdir -p ${tmpdir}
  fi

  cd ${tmpdir}

  for img in ${_arr[@]}; do
    local mask="mask_img_${RANDOM}.nii.gz"
    binarize_mri --img ${img} --out ${mask} --thresh 15
    local val=$(fslstats ${mask} -m)

    # if [[ ${val} -le ${min} ]]; then
    if (( $(echo "${val} < ${min}" | bc -l) )); then
      local min=${val}
      local best_img=${img}
    fi
  done

  cd ${cwd}
  echo ${best_img}

  if [[ ${cleanup} == "true" ]]; then
    local tmpdir=$(realpath ${tmpdir})
    chmod -R 755 ${tmpdir}
    rm -rf ${tmpdir}
  fi
}


#######################################
# Main function.
# Globals:
#   log
#   err
#######################################
main(){
  #
  # Parse arguments
  #============================
  
  # Check arguments
  if [[ ${#} -lt 1 ]]; then
    Usage >&2
    exit 1
  fi

  # Set defaults
  local cleanup="true"
  local glob_str=""
  local iterations=3

  while [[ ${#} -gt 0 ]]; do
    case "${1}" in
      -i|--img-dir) shift; local img_dir=${1} ;;
      -o|--out) shift; local out=${1} ;;
      -g|--glob-str) shift; local glob_str="${1}" ;;
      -r|--resolution) shift; local resolution=${1} ;;
      --iterations) shift; local iterations=${1} ;;
      --no-cleanup) local cleanup="false"; local cleanup_flag="--no-cleanup" ;;
      -h|-help|--help) Usage; ;;
      -*) echo_red "$(basename ${0}): Unrecognized option ${1}" >&2; Usage; ;;
      *) break ;;
    esac
    shift
  done

  #
  # Dependency checks
  #============================

  local deps=( python fslmaths fslstats mirtk )

  for dep in ${deps[@]}; do
    dependency_check ${dep}
  done

  #
  # Check arguments
  #============================
  
  if [[ -z ${img_dir} ]] || [[ ! -d ${img_dir} ]]; then
    exit_error "Image directory was not specified or does not exist."
  fi

  if [[ -z ${out} ]]; then
    exit_error "Output image not specified."
  fi

  if [[ ! -z ${resolution} ]]; then
    local resolution=$(python -c "print(round(${resolution},3))")
  else
    exit_error "Resolution was not specified."
  fi

  if [[ ! -z ${iterations} ]]; then
    local iterations=$(python -c "print(int('${iterations}'))")
  else
    exit_error "Number of iterations were not specified."
  fi

  #
  # Create output directory
  #============================

  outdir=$(dirname ${out})
  tmpdir=${outdir}/tmp${RANDOM}

  if [[ ! -d ${tmpdir} ]]; then
    mkdir -p ${tmpdir}
  fi

  # Global log files
  log=${outdir}/recon-img_${glob_str}.log
  err=${outdir}/recon-img_${glob_str}.err

  cd ${tmpdir}

  #
  # Create image list
  #============================

  local imgs=( $(ls ${img_dir}/*${glob_str}*.nii*) )

  # Log information
  echo "" >> ${log}

  for i in ${imgs[@]}; do
    echo "Image: ${i}" >> ${log}
  done

  echo "" >> ${log}

  #
  # Get slice thickness
  #============================

  local thick=()

  echo "Slice thickness (mm)" >> ${log}

  for i in ${imgs[@]}; do
    local _z=$(fslval ${i} pixdim3)
    local z=$(python -c "print(round(${_z},3))")
    local thick=( ${thick[@]} ${z} )

    # Log information
    echo "${z} mm: ${i}" >> ${log}
  done

  echo "" >> ${log}

  #
  # Select template image
  #============================

  local template=$(select_best_img ${cleanup_flag} ${imgs[@]})

  echo "Image template: ${template}" >> ${log}
  echo "" >> ${log}

  #
  # Create template image mask
  #============================

  run binarize_mri --img ${template} --thresh 15 --out img_mask.nii.gz
  local mask=$(realpath img_mask.nii.gz)

  echo "Template mask: ${mask}" >> ${log}
  echo "" >> ${log}

  #
  # Perform image super-resolution
  #================================

  run mirtk reconstruct \
  ${tmpdir}/img-recon-super.nii.gz \
  ${#imgs[@]} \
  ${imgs[@]} \
  -mask ${mask} \
  -template ${template} \
  -thickness ${thick[@]} \
  -resolution ${resolution} \
  -iterations ${iterations}

  cd ${outdir}

  # Convert NIFTI image values from DOUBLE to FLOAT to save on space
  run fslmaths ${tmpdir}/img-recon-super.nii.gz ${out} -odt float

  if [[ ${cleanup} == "true" ]]; then
    rm -rf ${tmpdir}
  fi
}

# Main function
main "${@}"
