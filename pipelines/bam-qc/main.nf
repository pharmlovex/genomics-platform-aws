#!/usr/bin/env nextflow
/*
 * bam-qc: mapped-read concordance check for aligned BAMs.
 *
 * For each sample, counts mapped reads two ways (samtools flagstat and
 * samtools idxstats) and reports where the counts disagree, then writes one
 * cohort-level summary. The same pipeline runs locally, on AWS Batch and on a
 * Kubernetes cluster by switching profiles, which is the point of the platform.
 */

nextflow.enable.dsl = 2

params.samplesheet = null
params.outdir      = 'results'

process SAMTOOLS_FLAGSTAT {
    tag "${sample}"
    cpus 1
    memory '1 GB'

    input:
    tuple val(sample), path(bam), path(bai)

    output:
    tuple val(sample), path("${sample}.flagstat.txt")

    script:
    """
    samtools flagstat -@ ${task.cpus} ${bam} > ${sample}.flagstat.txt
    """
}

process SAMTOOLS_IDXSTATS {
    tag "${sample}"
    cpus 1
    memory '1 GB'

    input:
    tuple val(sample), path(bam), path(bai)

    output:
    tuple val(sample), path("${sample}.idxstats.tsv")

    script:
    """
    samtools idxstats ${bam} > ${sample}.idxstats.tsv
    """
}

process CONCORDANCE {
    tag "${sample}"
    cpus 1
    memory '512 MB'
    publishDir "${params.outdir}/per-sample", mode: 'copy'

    input:
    tuple val(sample), path(flagstat), path(idxstats)

    output:
    path "${sample}.concordance.tsv"

    script:
    """
    concordance.py --sample ${sample} --flagstat ${flagstat} --idxstats ${idxstats} > ${sample}.concordance.tsv
    """
}

process SUMMARISE {
    cpus 1
    memory '512 MB'
    publishDir "${params.outdir}/summary", mode: 'copy'

    input:
    path tables

    output:
    path 'concordance.tsv'

    script:
    """
    set -- ${tables}
    head -n 1 "\$1" > concordance.tsv
    for f in "\$@"; do tail -n +2 "\$f"; done | sort >> concordance.tsv
    """
}

workflow {
    main:
    if (!params.samplesheet) {
        error "Missing --samplesheet (CSV with columns sample,bam,bai)"
    }

    samples = channel
        .fromPath(params.samplesheet, checkIfExists: true)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, file(row.bam, checkIfExists: true), file(row.bai, checkIfExists: true)) }

    flagstat = SAMTOOLS_FLAGSTAT(samples)
    idxstats = SAMTOOLS_IDXSTATS(samples)

    per_sample = CONCORDANCE(flagstat.join(idxstats))
    SUMMARISE(per_sample.collect())

    onComplete:
    log.info "bam-qc finished: ${workflow.success ? 'OK' : 'FAILED'} in ${workflow.duration}. Results: ${params.outdir}"
}
