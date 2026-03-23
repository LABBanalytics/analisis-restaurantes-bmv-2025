-- Comparativo de márgenes Alsea vs Gigante Restaurantes
SELECT 
    ff.empresa_id,
    ff.trimestre,
    ff.periodo,
    ff.ingresos_seg_restaurantes_trim           AS ingresos_rest_trim,
    ff.utilidad_operacion_trim                  AS utilidad_op_trim,
    ff.costo_ventas_trim                        AS costo_ventas_trim,
    ROUND((ff.utilidad_operacion_trim / 
           ff.ingresos_seg_restaurantes_trim) * 100, 2)  AS margen_operativo_pct,
    ROUND((ff.costo_ventas_trim / 
           ff.ingresos_seg_restaurantes_trim) * 100, 2)  AS ratio_costo_ingreso_pct,
    ff.vmt_crecimiento_pct
FROM fact_financiera ff
JOIN dim_empresa de ON ff.empresa_id = de.empresa_id
WHERE ff.trimestre = '3T'
ORDER BY ff.periodo DESC, ff.empresa_id;

TRUNCATE TABLE fact_contexto_externo;

-- 1. Eliminamos la restricción actual que solo protege la columna trimestre
ALTER TABLE fact_contexto_externo DROP CONSTRAINT fact_contexto_externo_pkey;

-- 2. Creamos una nueva llave combinando trimestre y periodo
-- Esto permite tener "1T" en 2024 y "1T" en 2025 sin errores
ALTER TABLE fact_contexto_externo ADD PRIMARY KEY (trimestre, periodo);

ALTER TABLE fact_contexto_externo DROP CONSTRAINT IF EXISTS fact_contexto_externo_pkey CASCADE;

ALTER TABLE fact_contexto_externo ADD PRIMARY KEY (trimestre, periodo);

TRUNCATE TABLE fact_contexto_externo;

-- Cruce de VMT con ICC y presencia de eventos deportivos
SELECT
    ce.trimestre,
    ce.periodo,
    ce.evento_deportivo_principal,
    ce.tipo_evento,
    ce.impacto_esperado_ventas,
    ce.evento_presente,
    ce.icc_promedio_trim_puntos,
    ce.tipo_cambio_mxn_usd,
    ce.vmt_crecimiento_pct                      AS vmt_gigante_rest,
    ff.vmt_crecimiento_pct                      AS vmt_alsea,
    (ff.vmt_crecimiento_pct - 
     ce.vmt_crecimiento_pct)                    AS gap_vmt_bps
FROM fact_contexto_externo ce
LEFT JOIN fact_financiera ff 
       ON ff.empresa_id = 'ALSEA'
      AND ff.trimestre  = ce.trimestre
      AND ff.periodo    = ce.periodo
ORDER BY ce.periodo, ce.trimestre;

-- Benchmark: trimestres CON evento vs SIN evento deportivo
SELECT
    ce.trimestre,
    ce.periodo,
    ce.evento_presente,
    ce.impacto_esperado_ventas,
    ce.evento_deportivo_principal,
    ce.icc_promedio_trim_puntos,
    ce.vmt_crecimiento_pct                          AS vmt_rest_gigante,
    AVG(ce.vmt_crecimiento_pct) 
        OVER (PARTITION BY ce.evento_presente)      AS vmt_promedio_por_evento,
    MAX(ce.vmt_crecimiento_pct) 
        OVER (PARTITION BY ce.evento_presente)      AS vmt_maximo_por_evento
FROM fact_contexto_externo ce
WHERE ce.empresa_ref = 'GIGANTE'
ORDER BY ce.periodo, ce.trimestre;

-- Versión mejorada Pregunta 3: enfocada en lo que SÍ tienes
SELECT
    ce.trimestre,
    ce.periodo,
    ce.evento_presente,
    ce.impacto_esperado_ventas,
    ce.icc_promedio_trim_puntos,
    ce.tipo_cambio_mxn_usd,
    ce.evento_deportivo_principal,
    -- Proyección BPS Mundial 2026
    CASE 
        WHEN ce.impacto_esperado_ventas = 'Muy Alto' THEN 1.70 + 2.50
        WHEN ce.impacto_esperado_ventas = 'Alto'     THEN 1.70 + 1.50
        WHEN ce.impacto_esperado_ventas = 'Medio-Bajo' THEN 1.70 + 0.50
        ELSE 1.70
    END                                         AS vmt_proyectado_pct,
    CASE 
        WHEN ce.impacto_esperado_ventas = 'Muy Alto' THEN 2.50
        WHEN ce.impacto_esperado_ventas = 'Alto'     THEN 1.50
        WHEN ce.impacto_esperado_ventas = 'Medio-Bajo' THEN 0.50
        ELSE 0
    END                                         AS bps_adicionales_estimados,
    -- Comparativo vs Alsea para cerrar GAP
    ROUND((4.10 - (
        CASE 
            WHEN ce.impacto_esperado_ventas = 'Muy Alto' THEN 1.70 + 2.50
            WHEN ce.impacto_esperado_ventas = 'Alto'     THEN 1.70 + 1.50
            WHEN ce.impacto_esperado_ventas = 'Medio-Bajo' THEN 1.70 + 0.50
            ELSE 1.70
        END)), 2)                               AS gap_residual_vs_alsea
FROM fact_contexto_externo ce
WHERE ce.empresa_ref = 'GIGANTE'
ORDER BY ce.periodo, ce.trimestre;

-- Comparativo de KPIs digitales y operativos
SELECT
    ff.empresa_id,
    ff.trimestre,
    ff.periodo,
    ff.ventas_digitales_pct,
    ff.vmt_crecimiento_pct,
    ff.margen_ebitda_pct,
    ff.apertura_unidades_trim,
    ff.num_unidades_total,
    ROUND(ff.ingresos_seg_restaurantes_trim / 
          NULLIF(ff.num_unidades_total, 0), 2)   AS ingreso_por_unidad,
    ff.deuda_neta_ebitda_ratio
FROM fact_financiera ff
WHERE ff.trimestre = '3T'
  AND ff.periodo   = '2025'
ORDER BY ff.empresa_id;

-- Análisis integral: GAP histórico + contexto + proyección
SELECT
    ce.trimestre,
    ce.periodo,
    ce.evento_deportivo_principal,
    ce.impacto_esperado_ventas,
    ce.icc_promedio_trim_puntos,
    ce.tipo_cambio_mxn_usd,
    ce.vmt_crecimiento_pct                          AS vmt_gigante,
    ff.vmt_crecimiento_pct                          AS vmt_alsea,
    ROUND((ff.vmt_crecimiento_pct - 
           ce.vmt_crecimiento_pct), 2)              AS gap_vmt,
    gr.ingresos_trim_mdp                            AS ingresos_gigante_rest,
    gr.utilidad_operacion_trim_mdp,
    ROUND((gr.utilidad_operacion_trim_mdp / 
           NULLIF(gr.ingresos_trim_mdp, 0)) * 100, 2) AS margen_op_gigante_pct
FROM fact_contexto_externo ce
LEFT JOIN fact_financiera ff
       ON ff.empresa_id = 'ALSEA'
      AND ff.trimestre  = ce.trimestre
      AND ff.periodo    = ce.periodo
LEFT JOIN gigante_restaurantes gr
       ON gr.empresa_id = 'GIGANTE'
      AND gr.trimestre  = ce.trimestre
      AND gr.periodo    = ce.periodo
ORDER BY ce.periodo, ce.trimestre;

