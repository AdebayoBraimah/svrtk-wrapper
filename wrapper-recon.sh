#!/usr/bin/env bash
# -*- coding: utf-8 -*-
# :set number tabstop=2 shiftwidth=2 fileformat=unix expandtab

# Load modules
module load mirtk/2.0.0
module load fsl/6.0.5

# Test code
# img_dir=/scratch/brac4g/test_data_recon/original_data/T2
# out=/scratch/brac4g/test_data_recon/test4/recon-img.nii.gz
# resolution=1
# glob_str="T2"
# 
# bsub -M 50000 -W 10000 -n 1 -R "span[hosts=1]" -J img-recon-test \
# ./recon-img.sh --img-dir ${img_dir} --out ${out} --resolution ${resolution} --glob-str ${glob_str}


# Variables
# scriptsdir=$(dirname $(realpath ${0}))
scriptsdir=/scratch/brac4g/test_data_recon
parent_img_dir=/scratch/brac4g/BPD_Brains_QC
parent_out_dir=/scratch/brac4g/image_reconstructions

# Arrays
resolutions=( 1 0.75 0.5 )
mods=( T2 T1 )

subs=( $(cd ${parent_img_dir}; ls -d s*) )

for sub in ${subs[@]}; do
	for mod in ${mods[@]}; do
		for resolution in ${resolutions[@]}; do

			imgdir=$(realpath ${parent_img_dir}/${sub}/*20*)
			outdir=${parent_out_dir}/resolution-${resolution}mm/${sub}

			echo "Processing: sub: ${sub} mod: ${mod} resolution: ${resolution}"

			bsub -M 64000 -W 10000 -n 1 -R "span[hosts=1]" -J ${sub}-${resolution} \
			${scriptsdir}/recon-img.sh \
			--img-dir ${imgdir} \
			--out ${outdir}/${sub}-${mod}.nii.gz \
			--resolution ${resolution} \
			--glob-str ${mod}
		done
	done
done

