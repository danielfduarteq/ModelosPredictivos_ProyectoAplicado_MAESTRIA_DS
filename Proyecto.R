#Informe OEE

      ## CARGA----
"Librerias"
library(readxl)  #Leer archivos de excel en R
library(dplyr) #Manipulacion de datos
library(tidyr) #Listado de datos
library(tidyverse) #API Conexion Google
library(googledrive) #Conexion a Drive (OEE)
library(googlesheets4) #Conexion a Google Sheets (OEE)
library(writexl) #Guardar archivos .xls (excel)
library(openxlsx) #Guardar archivos .xls (excel)
library(readr) #Guardar archivos .csv
library(stringr) #Omitir vacios y NA
library(knitr) #Tablas formateadas
library(DT)
library(plotly)
library(lubridate)

### DB OEE DATA ----

# Ruta del archivo de google sheets (OEE - Google Forms)
GOOGLE_SHEET <- "https://docs.google.com/spreadsheets/d/1nxKfXegq8QffGvml0O_syCb3w6jP3k_wmCTtk4UEpaM"


# Leer cada hoja de OEE-Google Forms por separado
OEE_DATA_ORIGINAL <- read_sheet(GOOGLE_SHEET, sheet = "Form Responses 1")
TRENES <- read_sheet(GOOGLE_SHEET, sheet = "TRENES")

#Copia de seguridad OEE_DATA Original
write_xlsx(OEE_DATA_ORIGINAL, "C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/OEE_DATA_ORIGINAL.xlsx")
OEE_DATA <- OEE_DATA_ORIGINAL #Hacer copia








### DB PLAN DE PRODUCCION----

# Leer el plan de produccion (FPR-2 en excel ubicado en PUBLIC)
PLAN_PROTECNICA <- read_excel("C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/BIABLE_MANUFACTURA.xlsx", sheet = "Plan Protecnica")

#Seleccion de variables (solo columnas de interés para el analisis)
PLAN_PROTECNICA <- select(PLAN_PROTECNICA, c(PLANTA, TREN, PRODUCTO, LOTE, STATUS, EQUIPO, OBSERVACIONES, PRESENTACIONES, `Kg programados`, `Kg fabricados`, REFERENCIA, SEMANA, CUMPLE, MES, AÑO))
PLAN_PROTECNICA$COMPAÑIA <- "PROTECNICA"

#Conversion de variables (convierte lote a tipo caracter)
PLAN_PROTECNICA$LOTE <- as.character(PLAN_PROTECNICA$LOTE)

# Filtrar por P1A/P1B
PLAN_PROTECNICA <- PLAN_PROTECNICA %>%
  filter(PLANTA %in% c("P1A", "P1B"))





### DB ENTREGA DE PRODUCCION----

#Leer capacidades nominales de planta y estandar por producto
CAPACIDADES_NOMINALES_TREN <- read_excel("C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/BIABLE_MANUFACTURA.xlsx",
                                    sheet = "CAPACIDADES",
                                    skip = 4)
STD_HORAS <- read_excel("C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/BIABLE_MANUFACTURA.xlsx",
                        sheet = "STD_HORAS")
# Leer entregas de produccion (EP en excel ubicado en PUBLIC)
PRODUCCION_PROTECNICA <- read_excel("C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/BIABLE_MANUFACTURA.xlsx",
                                    sheet = "Entrega Protecnica",
                                    skip = 4)

# Filtrar por UBICACION_PLANTA = "CALI"
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(UBICACIÓN_PLANTA == "CALI")

#Filtar solo las columnas de interes
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(`Tipo de Documento` == "EP",
         `CLASE DE OP` %in% c("PO4", "OP1"),  # Solo se selecciona las entregas de OP
         TREN %in% c("RXyMIXCALIENTE", "MEZCLA DOS FASES", "ESTERIFICACION", "MEZCLASIMPLE")) %>%  # Filtrar por TREN
  select(-`Ext1_detalle Item`) %>%  # Eliminamos EXT1
  group_by(Periodo, Fecha, `Referencia Item`, `Nombre Item`, OP, RUTA,
           `DESC. RUTA`, `CLASE DE OP`, TREN, UBICACIÓN_PLANTA, `LOTE ENTREGA`) %>%
  summarise(across(c(Costo_prom_ent, Costo_mo_en_ent, Costo_cif_en_ent, COSTO_MP_EN_ENT, KG),
                   sum, na.rm = TRUE),
            .groups = "drop")



# Realizar el LEFT JOIN usando los nombres correctos de las claves
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  left_join(STD_HORAS %>% select(REFERENCIA, MIN, MAX),
            by = c("Referencia Item" = "REFERENCIA"))

# Generar la nueva columna HORAS con un valor aleatorio entre MIN y MAX, redondeado.
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  mutate(
    HORAS = round(runif(n(), min = MIN, max = MAX))  # Genera número aleatorio entre MIN y MAX y lo redondea.
  ) %>%
  select(-MIN, -MAX)  # Eliminar las columnas MIN y MAX.

PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%filter(!is.na(HORAS)) #Filtrar NaN
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>% filter(Periodo != "202503") #Periodo de tiempo 202301 a 202502







## TRANSFORMACION ----
### DB OEE DATA ----


# Eliminar columnas
OEE_DATA <- OEE_DATA %>%
  select(-c(`PLANTA DE PRODUCCIÓN`, PRODUCTO_P1, PRODUCTO_P2, PRODUCTO_P3, PRODUCTO_P4, PRODUCTO_P5, PRODUCTO_P6,
            REACTOR_P1, REACTOR_P2, REACTOR_P3, REACTOR_P4, REACTOR_P5, REACTOR_P6,
            LOTE_BATCH, LOTE_FLOW,
            CANTIDAD_BATCH, CANTIDAD_FLOW,
            `HORA ETAPA_BATCH`, `HORA ETAPA_FLOW`,
            `TIPO REPORTE_BATCH`, `TIPO REPORTE_FLOW`,
            `ETAPA DEL PROCESO_BATCH [PROCESO]`, `ETAPA DEL PROCESO_FLOW [PROCESO]`, EQUIPO_ANT, LOTE_ETAPA, VALIDACION))

# Convertir columnas (formatos)
OEE_DATA$`USUARIO REGISTRO` <- as.character(OEE_DATA$`USUARIO REGISTRO`) # Convertir usuario registro a carácter (texto)
OEE_DATA$LOTE <- as.character(OEE_DATA$LOTE) # Convertir lote a carácter (texto)
OEE_DATA <- OEE_DATA %>% rename(`HORA REGISTRO` = Timestamp) # Renombrar columnas de Timestamp(hora registro sistema)
OEE_DATA <- OEE_DATA %>% rename(REACTOR = EQUIPO) # Renombrar columnas de EQUIPO a REACTOR
OEE_DATA <- OEE_DATA %>% rename(`PLANTA DE PRODUCCIÓN` = PLANTA) # Renombrar columnas de PLANTA A PLANTA DE PRODUCCIÓN
OEE_DATA <- OEE_DATA %>% rename(`TIPO DE PROCESO` = `TIPO PROCESO`) # Renombrar columnas de TIPO PROCESO A TIPO DE PROCESO
OEE_DATA <- OEE_DATA %>%
  mutate(
    AÑO = substr(PERIODO, 1, 4),
    MES = substr(PERIODO, 5, 6)
  )

# Seleccionar y reordenar columnas
Orden <- c("HORA REGISTRO", "USUARIO REGISTRO", "PLANTA DE PRODUCCIÓN", "PRODUCTO",
           "REACTOR", "LOTE", "CANTIDAD", "HORA ETAPA", "TIPO REPORTE", "ETAPA",
           "TIPO DE PARADA", "CAUSA PARADA", "TIPO DE PROCESO", "REGISTRO COMPLETO", "PERIODO", "SEMANA", "AÑO", "MES")
OEE_DATA <- OEE_DATA %>% select(all_of(Orden))

# Reemplazar valores vacíos o NA en ETAPA, TIPO DE PARADA y CAUSA PARADA
OEE_DATA <- OEE_DATA %>%
  mutate(
    ETAPA = ifelse(is.na(ETAPA) | ETAPA == "", "PARADA", ETAPA),
    `TIPO DE PARADA` = replace_na(`TIPO DE PARADA`, "-"),
    `CAUSA PARADA` = replace_na(`CAUSA PARADA`, "-"),

    # Reemplazar "_" por "-" en LOTE
    LOTE = str_replace_all(LOTE, "_", "-"),

    # Eliminar "." y "," en LOTE
    LOTE = str_replace_all(LOTE, "[.,]", ""),

    # Convertir LOTE a minúsculas
    LOTE = str_to_lower(LOTE),

    # Limpiar CANTIDAD: quitar comas, puntos y caracteres no numéricos
    CANTIDAD = str_replace_all(CANTIDAD, "[,\\.]", ""),
    CANTIDAD = str_replace_all(CANTIDAD, "[^\\d]", ""),

    # Convertir CANTIDAD a numérico y reemplazar NA con 0
    CANTIDAD = as.integer(ifelse(CANTIDAD == "", NA, CANTIDAD)),
    CANTIDAD = replace_na(CANTIDAD, 0)
  )

"Eliminar duplicados"
TRENES <- TRENES %>%
  distinct(`Nombre Item`, .keep_all = TRUE)

"Realizar los joins entre las bases de datos"
OEE_DATA <- OEE_DATA %>%
  left_join(select(TRENES, `Nombre Item`, `TREN PRODUCTIVO`), by = c("PRODUCTO" = "Nombre Item")) %>%
  left_join(select(TRENES, `Nombre Item`, COMPAÑIA), by = c("PRODUCTO" = "Nombre Item"))

"Eliminar duplicados (OEE)"
# Crear una columna concatenada para PRODUCTO, LOTE y ETAPA
OEE_DATA <- OEE_DATA %>%
  mutate(ID_UNICO = paste(PRODUCTO, LOTE, ETAPA, `HORA ETAPA`, sep = "_"))

OEE_DATA <- OEE_DATA %>%
  arrange(ID_UNICO, desc(`HORA REGISTRO`)) %>%
  distinct(ID_UNICO, .keep_all = TRUE)  # Mantener solo el primer registro de cada grupo

#Ordenar por lote, hora, etapa (OEE)
OEE_DATA <- OEE_DATA %>%
  arrange(
    LOTE,                              # Ordenar por LOTE (ascendente por defecto)
    `HORA ETAPA`,                      # Ordenar por HORA ETAPA de más antigua a más reciente (ascendente)
    desc(`HORA REGISTRO`)              # Ordenar por HORA REGISTRO de más reciente a más antigua (descendente)
  )

"Calcular horas de proceso y parada"

# Calcular la diferencia de tiempo entre etapas por PRODUCTO y LOTE
OEE_DATA <- OEE_DATA %>%
  arrange(PRODUCTO, LOTE, `HORA ETAPA`) %>%  # Ordenar por PRODUCTO, LOTE y HORA ETAPA
  group_by(PRODUCTO, LOTE) %>%               # Agrupar por PRODUCTO y LOTE
  mutate(
    HORAS = case_when(
      ETAPA == "TERMINADO" ~ 0,  # Si es "TERMINADO", poner 0
      TRUE ~ as.numeric(difftime(lead(`HORA ETAPA`), `HORA ETAPA`, units = "hours"))  # Calcular diferencia en horas
    )
  ) %>%
  ungroup() %>%
  mutate(
    HORAS = replace_na(HORAS, 0),  # Reemplazar NA's con 0
    HORAS = round(HORAS, 2)  # Redondear a 2 decimales
  )

"Filtrar solo P1A/P1B"
OEE_DATA <- OEE_DATA %>%
  filter(`PLANTA DE PRODUCCIÓN` %in% c("P1A", "P1B"))

# Eliminar registros donde HORAS > 144 y REGISTRO_COMPLETO sea "NO""
OEE_DATA <- OEE_DATA %>%
  filter(!(HORAS > 144 | `REGISTRO COMPLETO` == "NO"))  # Eliminar filas donde HORAS > 144 y REGISTRO_COMPLETO = "NO"

#Copia de seguridad OEE_DATA
write_xlsx(OEE_DATA, "C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/OEE_DATA.xlsx")
colnames(OEE_DATA)





## PREMODELADO----
### AGRUPACION DATA ----

"Agrupar OEE_DATA para calculo de disponibilidad por TREN(linea)"
# Cargar las librerías necesarias
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)

# Filtrar los trenes específicos (ESTERIFICACION, MEZCLA DOS FASES, MEZCLASIMPLE, RXyMIXCALIENTE) y las columnas MES y AÑO
trenes_interes <- c("ESTERIFICACION", "MEZCLA DOS FASES", "MEZCLASIMPLE", "RXyMIXCALIENTE")

OEE_filtrado <- OEE_DATA %>%
  filter(`TREN PRODUCTIVO` %in% trenes_interes, `TIPO REPORTE` %in% c("PROCESO", "PARADA"))  # Filtramos por los trenes y tipo reporte

# Crear una nueva columna de "Fecha" combinando MES y AÑO, y luego convertirla en un formato adecuado
OEE_filtrado <- OEE_filtrado %>%
  mutate(
    Fecha = as.Date(paste0(AÑO, "-", MES, "-01"))
  )

# Calcular las horas de proceso y horas de parada por mes, tren y año
OEE_AGREGADO <- OEE_filtrado %>%
  group_by(`TREN PRODUCTIVO`, Fecha, MES, AÑO, `TIPO REPORTE`) %>%
  summarise(
    HORAS = sum(HORAS, na.rm = TRUE),  # Sumar las horas por tipo de reporte
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = `TIPO REPORTE`, values_from = HORAS, values_fill = list(HORAS = 0)) %>%
  mutate(
    HORAS_PROCESO = `PROCESO`,  # Asignar las horas de proceso
    HORAS_PARADA = `PARADA`,  # Asignar las horas de parada
    TOTAL_HORAS = HORAS_PROCESO + HORAS_PARADA,  # Calcular el total de horas
    DISPONIBILIDAD = HORAS_PROCESO / TOTAL_HORAS  # Calcular la disponibilidad (porcentaje de horas de proceso)
  ) %>%
  arrange(Fecha, `TREN PRODUCTIVO`)  # Ordenar por Fecha y Tren Productivo




"Agrupar PRODUCCION_PROTECNICA para calculo de costo, horas y kg totales por TREN(linea)"
# Cargar las librerías necesarias
library(dplyr)
library(lubridate)

# Paso 1: Convertir las fechas a solo mes y año, y luego agrupar por esa nueva fecha (primer día de cada mes)
PRODUCCION_AGREGADO <- PRODUCCION_PROTECNICA %>%
  mutate(
    # Convertir la fecha a primer día del mes usando `floor_date()` de lubridate
    Fecha = floor_date(Fecha, "month")  # Esto te dará el primer día del mes de cada fecha
  ) %>%
  group_by(Fecha, TREN) %>%
  summarise(
    Costo_prom_ent = sum(Costo_prom_ent, na.rm = TRUE),
    Costo_mo_en_ent = sum(Costo_mo_en_ent, na.rm = TRUE),
    Costo_cif_en_ent = sum(Costo_cif_en_ent, na.rm = TRUE),
    COSTO_MP_EN_ENT = sum(COSTO_MP_EN_ENT, na.rm = TRUE),
    KG = sum(KG, na.rm = TRUE),
    HORAS = sum(HORAS, na.rm = TRUE),
    .groups = 'drop'  # Eliminar los grupos de agrupamiento
  )
PRODUCCION_AGREGADO$Fecha <- as.Date(PRODUCCION_AGREGADO$Fecha)


"Agrupar CAPACIDAD_NOMINALES_TREN para calculo de capacidad en kg totales por mes por TREN(linea)"

# Resumir las capacidades nominales a nivel mensual por TREN
CAPACIDAD_AGREGADO <- CAPACIDADES_NOMINALES_TREN %>%
  group_by(`TREN PRODUCTIVO`) %>%
  summarise(
    CAPACIDAD_NOMINAL_MES = sum(`CAPACIDAD/MES`, na.rm = TRUE),  # Sumar capacidad nominal mensual
    HORAS_TOTALES = sum(HORAS, na.rm = TRUE)  # Sumar las HORAS (ajusta el nombre de la columna si es diferente)
  )


"Unificar base de datos para modelos predictivos"

# Unir solo las columnas necesarias (DISPONIBILIDAD de OEE_AGREGADO)
BASE_MODELO <- PRODUCCION_AGREGADO %>%
  left_join(OEE_AGREGADO %>% select(TREN = `TREN PRODUCTIVO`, Fecha, DISPONIBILIDAD),
            by = c("TREN", "Fecha")) %>%
  left_join(CAPACIDAD_AGREGADO, by = c("TREN" = "TREN PRODUCTIVO"))



"Imputar disponibilidad del tren (OEE DATA inicia en Abril 2024) "
library(dplyr)
library(lubridate)

# Calcular el promedio de DISPONIBILIDAD entre septiembre 2024 y febrero 2025
promedio_disponibilidad <- BASE_MODELO %>%
  filter(Fecha >= ymd("2024-09-01") & Fecha <= ymd("2025-02-01")) %>%
  summarise(promedio = mean(DISPONIBILIDAD, na.rm = TRUE)) %>%
  pull(promedio)

# Imputar los valores de DISPONIBILIDAD para los meses anteriores a agosto 2024
BASE_MODELO <- BASE_MODELO %>%
  mutate(
    DISPONIBILIDAD = case_when(
      is.na(DISPONIBILIDAD) & Fecha < ymd("2024-08-01") ~ promedio_disponibilidad,  # Imputar con el promedio para las fechas antes de agosto 2024
      TRUE ~ DISPONIBILIDAD  # Mantener los valores existentes
    )
  )

BASE_MODELO$DISPONIBILIDAD[is.na(BASE_MODELO$DISPONIBILIDAD)] <- mean(BASE_MODELO$DISPONIBILIDAD, na.rm = TRUE)


"Calcular ocupacion en kg y en horas"
BASE_MODELO <- BASE_MODELO %>%
  mutate(
    OCUPACION_HORAS = HORAS / HORAS_TOTALES,                # Calcular ocupación en horas
    OCUPACION_KG = KG / CAPACIDAD_NOMINAL_MES               # Calcular ocupación en kg
  )




### FEATURE ENGINEERING ----

"IMPORTANCIA DE LAS CARACTERISTICAS"
library(caret)
library(randomForest)
library(ggplot2)

# Eliminar las columnas 'Fecha' y 'TREN'
BASE_MODELO_SIN_FECHA_TREN <- BASE_MODELO[, !(colnames(BASE_MODELO) %in% c("Fecha", "TREN"))]

# Entrenar el modelo sin las variables 'Fecha' y 'TREN'
set.seed(123)
modelo_importancia <- train(DISPONIBILIDAD ~ ., data = BASE_MODELO_SIN_FECHA_TREN,
                            method = "rf", importance = TRUE)

# Obtener la importancia de las variables
importancia <- varImp(modelo_importancia)
df_importancia <- data.frame(Variable = rownames(importancia$importance),
                             Importancia = importancia$importance$Overall)

# Ordenar de mayor a menor
df_importancia <- df_importancia[order(df_importancia$Importancia, decreasing = TRUE), ]

# Graficar
ggplot(df_importancia, aes(x = reorder(Variable, Importancia), y = Importancia)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_text(aes(label = round(Importancia, 1)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  labs(title = "Importancia de Características (Random Forest)",
       x = "Variables", y = "Importancia") +
  theme_minimal()


### CORRELACION ----
"MAPA DE CALOR: CORRELACION DE VARIABLES"

library(ggcorrplot)

# Calcular matriz de correlación
cor_matrix <- cor(BASE_MODELO %>%
                    select(HORAS, KG, Costo_prom_ent, DISPONIBILIDAD),
                  use = "complete.obs")

# Crear el mapa de calor con mejor contraste
ggcorrplot(cor_matrix,
           method = "square",  # Celdas cuadradas en lugar de círculos
           type = "lower",  # Solo muestra la mitad inferior de la matriz
           lab = TRUE,  # Muestra los valores numéricos
           lab_size = 4,  # Tamaño de etiquetas
           colors = c("#6D9EC1", "white", "#E46726"),  # Azul-Negro-Rojo para negativo/neutro/positivo
           title = "Mapa de Calor de Correlación",
           outline.col = "gray")  # Contorno para mejor visibilidad





  ### K-MEANS ----
"K-MEANS"

library(ggplot2)
library(dplyr)
library(cluster)

# Seleccionar solo variables numéricas relevantes
data_cluster <- PRODUCCION_PROTECNICA %>%
  select(HORAS, KG) %>%
  mutate(MT = KG / 1000)  # Convertimos KG a MT para consistencia

# Estandarizar los datos
data_scaled <- scale(data_cluster)

# Determinar el número óptimo de clusters con el método del codo
wss <- numeric(10)
for (i in 1:10) {
  wss[i] <- sum(kmeans(data_scaled, centers = i, nstart = 10)$tot.withinss)
}

# Crear el gráfico con ggplot2
elbow_plot <- data.frame(Clusters = 1:10, WSS = wss)

ggplot(elbow_plot, aes(x = Clusters, y = WSS)) +
  geom_line(color = "blue", size = 1.2) +   # Línea azul más gruesa
  geom_point(color = "red", size = 3) +    # Puntos rojos
  geom_vline(xintercept = 3, linetype = "dashed", color = "gray") +  # Línea en K óptimo
  labs(title = "Método del Codo para Selección de K",
       x = "Número de Clusters (K)",
       y = "Suma de Cuadrados Dentro del Cluster (WSS)") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))



# Aplicar K-Means con el número óptimo de clusters (k)
set.seed(123)
km_model <- kmeans(data_scaled, centers=4, nstart=25)

# Agregar clusters a la base original
PRODUCCION_PROTECNICA$Cluster <- as.factor(km_model$cluster)

#  Cambiar los ejes: X = MT, Y = HORAS
ggplot(PRODUCCION_PROTECNICA, aes(x = KG/1000, y = HORAS, color = Cluster)) +
  geom_point(size = 3, alpha = 0.7) +
  labs(title = "K-Means Clustering en Producción",
       x = "Producción (MT)", y = "Total Horas", color = "Cluster") +
  theme_minimal()


library(cluster)

# Calcular la métrica de Silhouette
sil <- silhouette(km_model$cluster, dist(data_scaled))

# Obtener el coeficiente promedio
silhouette_avg <- mean(sil[, 3])
print(paste("Coeficiente de Silhouette promedio:", round(silhouette_avg, 4)))





### GRAFICAS ----
"GRAFICA HORAS DE PROCESO VS HORAS DE PARADA: OEE DATA"

#Graficar la Disponibilidad para cada Tren Productivo a través del tiempo
ggplot(OEE_AGREGADO, aes(x = Fecha, y = DISPONIBILIDAD, color = `TREN PRODUCTIVO`, group = `TREN PRODUCTIVO`)) +
  geom_line(size = 1) +  # Usamos geom_line para mostrar la evolución en el tiempo
  geom_point(size = 2) +  # Agregamos puntos para ver claramente la evolución en cada mes
  labs(title = "Evolución de la Disponibilidad por Tren Productivo",
       x = "Mes y Año",
       y = "Disponibilidad (%)",
       color = "Tren Productivo") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +  # Rotar los textos del eje X
  facet_wrap(~ `TREN PRODUCTIVO`, scales = "free_y") +  # Crear facetas por Tren Productivo, cada tren tiene su propio gráfico
  expand_limits(y = 0) +  # Establecer el límite inferior del eje Y en 0
  geom_text(aes(label = scales::percent(DISPONIBILIDAD, accuracy = 0.1)),  # Etiquetas con disponibilidad
            position = position_dodge(width = 0.5), color = "black", size = 3, vjust = -0.5)  # Ajuste de posición y tamaño





"GRAFICA HISTORICO KG FABRICADOS POR TREN"

library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)  # Para formatear etiquetas sin notación científica

# Filtrar solo los trenes de interés y los años 2023 y 2024
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(TREN %in% trenes_interes, year(Fecha) %in% c(2023, 2024)) %>%
  mutate(MES = format(Fecha, "%Y-%m"))  # Extraer año-mes

# Agrupar por mes y tren productivo, sumando los KG y convirtiéndolos a toneladas (MT)
grafico_data <- PRODUCCION_PROTECNICA %>%
  group_by(MES, TREN) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")  # Convertir KG a MT

# Crear el gráfico de líneas
ggplot(grafico_data, aes(x = MES, y = TOTAL_MT, color = TREN, group = TREN)) +
  geom_line(size = 1) +  # Línea más gruesa
  geom_point(size = 3) +  # Puntos en cada mes
  geom_text(aes(label = round(TOTAL_MT, 1)), vjust = -0.5, size = 4) +  # Etiquetas con valores sin notación científica
  labs(title = "Evolución de Producción (MT) por Tren Productivo - Año 2023-2024",
       x = "Periodo (Mes)",
       y = "Total MT",
       color = "Tren Productivo") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +  # Rotar etiquetas del eje X
  scale_x_discrete(limits = unique(grafico_data$MES)) +  # Asegurar orden de los meses
  scale_y_continuous(labels = scales::comma)  # Evitar notación científica en eje Y




"GRAFICA HISTORICO HORAS POR TREN"

# Cargar las librerías necesarias
library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)  # Para formatear etiquetas sin notación científica

# Filtrar solo los trenes de interés y los años 2023 y 2024
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(TREN %in% trenes_interes, year(Fecha) %in% c(2023, 2024)) %>%
  mutate(MES = format(Fecha, "%Y-%m"))  # Extraer año-mes

# Agrupar por mes y tren productivo, sumando las HORAS
grafico_data <- PRODUCCION_PROTECNICA %>%
  group_by(MES, TREN) %>%
  summarise(TOTAL_HORAS = sum(HORAS, na.rm = TRUE), .groups = "drop")  # Sumar las horas

# Crear el gráfico de líneas
ggplot(grafico_data, aes(x = MES, y = TOTAL_HORAS, color = TREN, group = TREN)) +
  geom_line(size = 1) +  # Línea más gruesa
  geom_point(size = 3) +  # Puntos en cada mes
  geom_text(aes(label = round(TOTAL_HORAS, 1)), vjust = -0.5, size = 4) +  # Etiquetas con valores de horas
  labs(title = "Evolución de Horas de Producción por Tren Productivo - Año 2023-2024",
       x = "Periodo (Mes)",
       y = "Total Horas",
       color = "Tren Productivo") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +  # Rotar etiquetas del eje X
  scale_x_discrete(limits = unique(grafico_data$MES)) +  # Asegurar orden de los meses
  scale_y_continuous(labels = scales::comma)  # Evitar notación científica en eje Y



"GRAFICA DE CORRELACIÓN (KG VS HORAS) POR TREN"
library(ggplot2)
library(dplyr)
library(scales)

# Filtrar solo los trenes de interés y los años 2023 y 2024
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(TREN %in% trenes_interes, year(Fecha) %in% c(2023, 2024)) %>%
  mutate(MES = format(Fecha, "%Y-%m"))  # Extraer año-mes

# Crear el gráfico de dispersión con facetado
ggplot(PRODUCCION_PROTECNICA, aes(x = HORAS, y = KG / 1000)) +
  geom_point(size = 3, alpha = 0.7, color = "steelblue") +  # Puntos en azul con transparencia
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed", color = "red") +  # Línea de tendencia en rojo
  facet_wrap(~TREN, scales = "free") +  # Un gráfico por tren
  labs(title = "Correlación entre Horas y Producción (MT) por Tren Productivo",
       x = "Total Horas",
       y = "Producción (MT)") +
  theme_minimal() +
  scale_x_continuous(labels = scales::comma) +  # Evita notación científica en X
  scale_y_continuous(labels = scales::comma)  # Evita notación científica en Y



## GRAFICAS----
"GRAFICA HISTORICO KG FABRICADOS POR TREN"
library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)

# Filtrar solo los trenes de interés y los años 2023 y 2024
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(TREN %in% trenes_interes, year(Fecha) %in% c(2023, 2024)) %>%
  mutate(MES = format(Fecha, "%Y-%m"))  # Extraer año-mes

# Agrupar por mes y tren productivo, sumando los KG y convirtiéndolos a toneladas (MT)
grafico_data <- PRODUCCION_PROTECNICA %>%
  group_by(MES, TREN) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")

# Crear el gráfico de líneas con facetas y escalas independientes, pero empezando en 0
ggplot(grafico_data, aes(x = MES, y = TOTAL_MT, color = TREN, group = TREN)) +
  geom_line(size = 1) +
  geom_point(size = 3) +
  geom_text(aes(label = round(TOTAL_MT, 1)), vjust = -0.5, size = 3) +
  labs(title = "Evolución de Producción (MT) por Tren Productivo - 2023 y 2024",
       x = "Periodo (Mes)",
       y = "Total MT") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  scale_x_discrete(limits = unique(grafico_data$MES)) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.1))) +
  facet_wrap(~TREN, ncol = 2, scales = "free_y")  # Escalas independientes en Y, pero comenzando en 0



### DESCOMPOSICIÓN SERIES DE TIEMPO----

# Cargar librerías necesarias
library(dplyr)
library(ggplot2)
library(lubridate)
library(forecast)

# Filtrar solo el tren de interés y los años 2023 y 2024
PRODUCCION_PROTECNICA <- PRODUCCION_PROTECNICA %>%
  filter(TREN == "ESTERIFICACION", year(Fecha) %in% c(2023, 2024, 2025)) %>%  # Filtrar por tren y años
  mutate(MES = floor_date(Fecha, "month")) %>%  # Convertir fechas a formato mes-año
  group_by(MES) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")  # Convertir KG a MT

# Convertir a serie de tiempo mensual
esterificacion_ts <- ts(PRODUCCION_PROTECNICA$TOTAL_MT,
                        start = c(2023, 1),
                        frequency = 12)

stl_result <- stl(esterificacion_ts, s.window = "periodic")
plot(stl_result)




# Filtrar solo el tren de interés y los años 2023 y 2024
PRODUCCION_FILTRADA <- PRODUCCION_PROTECNICA %>%
  filter(TREN == "RXyMIXCALIENTE", year(Fecha) %in% c(2023, 2024, 2025)) %>%  # Filtrar por tren y años
  mutate(MES = floor_date(Fecha, "month")) %>%  # Convertir fechas a formato mes-año
  group_by(MES) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")  # Convertir KG a MT

# Convertir a serie de tiempo mensual
rxmx_ts <- ts(PRODUCCION_FILTRADA$TOTAL_MT,
                        start = c(2023, 1),
                        frequency = 12)

stl_result <- stl(rxmx_ts, s.window = "periodic")
plot(stl_result)





# Filtrar solo el tren de interés y los años 2023 y 2024
PRODUCCION_FILTRADA <- PRODUCCION_PROTECNICA %>%
  filter(TREN == "MEZCLA DOS FASES", year(Fecha) %in% c(2023, 2024, 2025)) %>%  # Filtrar por tren y años
  mutate(MES = floor_date(Fecha, "month")) %>%  # Convertir fechas a formato mes-año
  group_by(MES) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")  # Convertir KG a MT

# Convertir a serie de tiempo mensual
mzdosfases_ts <- ts(PRODUCCION_FILTRADA$TOTAL_MT,
              start = c(2023, 1),
              frequency = 12)

stl_result <- stl(mzdosfases_ts, s.window = "periodic")
plot(stl_result)




# Filtrar solo el tren de interés y los años 2023 y 2024
PRODUCCION_FILTRADA <- PRODUCCION_PROTECNICA %>%
  filter(TREN == "MEZCLASIMPLE", year(Fecha) %in% c(2023, 2024, 2025)) %>%  # Filtrar por tren y años
  mutate(MES = floor_date(Fecha, "month")) %>%  # Convertir fechas a formato mes-año
  group_by(MES) %>%
  summarise(TOTAL_MT = sum(KG, na.rm = TRUE) / 1000, .groups = "drop")  # Convertir KG a MT

# Convertir a serie de tiempo mensual
mzsimple_ts <- ts(PRODUCCION_FILTRADA$TOTAL_MT,
                    start = c(2023, 1),
                    frequency = 12)

stl_result <- stl(mzsimple_ts, s.window = "periodic")
plot(stl_result)






































# ---- MODELADO ----



# Cargar librerías necesarias
library(ggplot2)
library(caret)
library(dplyr)
library(xgboost)
library(randomForest)  # Para RF
library(prophet)      # Para Prophet
library(scales)       # Para formatear ejes

# ---- PREPARACIÓN DE DATOS ----

# Imputar DISPONIBILIDAD con la mediana
BASE_MODELO$DISPONIBILIDAD[is.na(BASE_MODELO$DISPONIBILIDAD)] <- median(BASE_MODELO$DISPONIBILIDAD, na.rm = TRUE)

# Dividir los datos en entrenamiento (70%) y prueba (30%)
library(dplyr)
library(caret)

set.seed(123)

# Split por trenes
trainData <- BASE_MODELO %>%
  group_by(TREN) %>%
  group_modify(~ {
    idx <- createDataPartition(.x$KG, p = 0.7, list = FALSE)
    .x[idx, ]
  }) %>% ungroup()

testData <- BASE_MODELO %>%
  anti_join(trainData, by = c("TREN", "Fecha", "KG", "DISPONIBILIDAD", "HORAS", "Costo_prom_ent"))


# Identificar trenes únicos (común para todos los modelos)
trenes_unicos <- unique(BASE_MODELO$TREN)


# Crear listas para almacenar resultados
resultados_modelos <- list()
predicciones_modelos <- list()

# ---- FUNCIONES COMUNES ----

# Función para evaluar modelos (RMSE, MAE, MAPE, R²)
evaluar_modelo <- function(pred_train, pred_test, modelo_nombre) {
  # Eliminar NAs para cálculos precisos
  valid_train <- !is.na(pred_train)
  valid_test <- !is.na(pred_test)

  # Métricas en entrenamiento
  y_train <- trainData$KG[valid_train]
  y_pred_train <- pred_train[valid_train]

  rmse_train <- sqrt(mean((y_train - y_pred_train)^2, na.rm = TRUE))
  r2_train <- 1 - sum((y_train - y_pred_train)^2, na.rm = TRUE) / sum((y_train - mean(y_train))^2, na.rm = TRUE)
  mae_train <- mean(abs(y_train - y_pred_train), na.rm = TRUE)
  mape_train <- mean(abs((y_train - y_pred_train) / y_train), na.rm = TRUE) * 100

  # Métricas en prueba
  y_test <- testData$KG[valid_test]
  y_pred_test <- pred_test[valid_test]

  rmse_test <- sqrt(mean((y_test - y_pred_test)^2, na.rm = TRUE))
  r2_test <- 1 - sum((y_test - y_pred_test)^2, na.rm = TRUE) / sum((y_test - mean(y_test))^2, na.rm = TRUE)
  mae_test <- mean(abs(y_test - y_pred_test), na.rm = TRUE)
  mape_test <- mean(abs((y_test - y_pred_test) / y_test), na.rm = TRUE) * 100

  # Crear dataframe con resultados
  resultados <- data.frame(
    Modelo = modelo_nombre,
    Conjunto = c("Entrenamiento", "Prueba"),
    RMSE = c(rmse_train, rmse_test),
    MAE = c(mae_train, mae_test),
    MAPE = c(mape_train, mape_test),
    R2 = c(r2_train, r2_test)
  )

  return(resultados)
}

### ---- VALIDACIÓN CRUZADA POR TREN ----

library(caret)

# Control para K-fold CV (5 folds)
control_kfold <- trainControl(
  method = "cv",
  number = 5,
  verboseIter = FALSE
)

# Inicializar resultados
resultados_cv_trenes <- data.frame()

for (tren in trenes_unicos) {
  datos_tren <- trainData %>% filter(TREN == tren)

  # Evitar errores con pocos datos
  if (nrow(datos_tren) < 10) next

  # RLM
  modelo_rlm_cv <- train(
    KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent,
    data = datos_tren,
    method = "lm",
    trControl = control_kfold
  )

  # RF
  modelo_rf_cv <- train(
    KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent,
    data = datos_tren,
    method = "rf",
    trControl = control_kfold,
    tuneLength = 3
  )

  # XGBoost
  modelo_xgb_cv <- train(
    KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent,
    data = datos_tren,
    method = "xgbTree",
    trControl = control_kfold,
    tuneLength = 3
  )

  # Guardar resumen de resultados para cada tren
  resumen <- data.frame(
    TREN = tren,
    Modelo = c("RLM", "RF", "XGBoost"),
    RMSE = c(mean(modelo_rlm_cv$results$RMSE),
             mean(modelo_rf_cv$results$RMSE),
             mean(modelo_xgb_cv$results$RMSE)),
    R2 = c(mean(modelo_rlm_cv$results$Rsquared),
           mean(modelo_rf_cv$results$Rsquared),
           mean(modelo_xgb_cv$results$Rsquared))
  )

  resultados_cv_trenes <- bind_rows(resultados_cv_trenes, resumen)
}

# Visualización (tabla)
print(resultados_cv_trenes)



# ---- MODELO RLM ----

# Entrenar el modelo de regresión global
modelo_regresion <- lm(KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent, data = trainData)

# Predicciones en entrenamiento y prueba para RLM
pred_train_lm <- predict(modelo_regresion, newdata = trainData)
pred_test_lm <- predict(modelo_regresion, newdata = testData)

# Evaluar y guardar resultados de RLM
resultados_modelos[["RLM"]] <- evaluar_modelo(pred_train_lm, pred_test_lm, "RLM")

# Evaluación por tren para RLM
df_test_pred_rlm <- testData %>%
  mutate(pred = pred_test_lm)

resultados_trenes_rlm <- df_test_pred_rlm %>%
  group_by(TREN) %>%
  summarise(
    Modelo = "RLM",
    R2 = 1 - sum((KG - pred)^2, na.rm = TRUE) / sum((KG - mean(KG, na.rm = TRUE))^2, na.rm = TRUE),
    RMSE = sqrt(mean((KG - pred)^2, na.rm = TRUE)),
    MAE = mean(abs(KG - pred), na.rm = TRUE),
    MAPE = mean(abs((KG - pred) / KG), na.rm = TRUE) * 100
  )




# ---- MODELO XGBOOST ----

# Convertir los datos a formato de matriz para XGBoost
train_matrix <- xgb.DMatrix(data = as.matrix(trainData[, c("DISPONIBILIDAD", "HORAS", "Costo_prom_ent")]),
                            label = trainData$KG)
test_matrix <- xgb.DMatrix(data = as.matrix(testData[, c("DISPONIBILIDAD", "HORAS", "Costo_prom_ent")]),
                           label = testData$KG)

# Definir parámetros de XGBoost
params <- list(
  objective = "reg:squarederror",
  eval_metric = "rmse",
  eta = 0.1,
  max_depth = 6
)

# Entrenar el modelo XGBoost
modelo_xgb <- xgb.train(params = params,
                        data = train_matrix,
                        nrounds = 100,
                        watchlist = list(train = train_matrix, test = test_matrix),
                        early_stopping_rounds = 10,
                        verbose = 0)  # Reducir output

# Predicciones en entrenamiento y prueba para XGBoost
pred_train_xgb <- predict(modelo_xgb, train_matrix)
pred_test_xgb <- predict(modelo_xgb, test_matrix)

# Evaluar y guardar resultados de XGBoost
resultados_modelos[["XGBoost"]] <- evaluar_modelo(pred_train_xgb, pred_test_xgb, "XGBoost")

# Evaluación por tren para RF
# Preparar dataset de predicciones de test
df_test_pred_xgb <- testData %>%
  mutate(pred = pred_test_xgb)

# Evaluar por tren SOLO sobre testData
resultados_trenes_xgb <- df_test_pred_xgb %>%
  group_by(TREN) %>%
  summarise(
    Modelo = "XGBoost",
    R2 = 1 - sum((KG - pred)^2, na.rm = TRUE) / sum((KG - mean(KG, na.rm = TRUE))^2, na.rm = TRUE),
    RMSE = sqrt(mean((KG - pred)^2, na.rm = TRUE)),
    MAE = mean(abs(KG - pred), na.rm = TRUE),
    MAPE = mean(abs((KG - pred) / KG), na.rm = TRUE) * 100
  )


# ---- MODELO RF(RANDOM FOREST) ----

# Entrenar el modelo Random Forest
modelo_rf <- randomForest(KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent, data = trainData, ntree = 100)

# Predicciones en entrenamiento y prueba para RF
pred_train_rf <- predict(modelo_rf, newdata = trainData)
pred_test_rf <- predict(modelo_rf, newdata = testData)

# Evaluar y guardar resultados de RF
resultados_modelos[["RF"]] <- evaluar_modelo(pred_train_rf, pred_test_rf, "RF")

# Evaluación por tren para RF
# Preparar dataset de predicciones de test
df_test_pred_rf <- testData %>%
  mutate(pred = pred_test_rf)

# Evaluar por tren SOLO sobre testData
resultados_trenes_rf <- df_test_pred_rf %>%
  group_by(TREN) %>%
  summarise(
    Modelo = "RF",
    R2 = 1 - sum((KG - pred)^2, na.rm = TRUE) / sum((KG - mean(KG, na.rm = TRUE))^2, na.rm = TRUE),
    RMSE = sqrt(mean((KG - pred)^2, na.rm = TRUE)),
    MAE = mean(abs(KG - pred), na.rm = TRUE),
    MAPE = mean(abs((KG - pred) / KG), na.rm = TRUE) * 100
  )



# ---- MODELO PROPHET ----

# Crear función para entrenar modelo Prophet por tren
entrenar_prophet <- function(datos_tren) {
  # Preparar datos para Prophet
  df <- datos_tren %>%
    select(Fecha, KG) %>%
    rename(ds = Fecha, y = KG)

  # Entrenar modelo
  modelo <- prophet(df)

  return(modelo)
}

# Entrenar modelos Prophet por tren
modelos_prophet <- list()
for (tren in trenes_unicos) {
  datos_tren <- BASE_MODELO %>% filter(TREN == tren)
  modelos_prophet[[tren]] <- entrenar_prophet(datos_tren)
}

# Crear función para evaluar Prophet por tren
evaluar_prophet_por_tren <- function() {
  resultados <- data.frame()

  for (tren in trenes_unicos) {
    datos_tren <- BASE_MODELO %>%
      filter(TREN == tren) %>%
      select(Fecha, KG) %>%
      rename(ds = Fecha, y = KG)

    pred <- predict(modelos_prophet[[tren]], datos_tren)

    errores <- datos_tren$y - pred$yhat
    y_real <- datos_tren$y
    y_pred <- pred$yhat

    resultados <- bind_rows(resultados,
                            data.frame(
                              TREN = tren,
                              Modelo = "Prophet",
                              R2 = 1 - sum((y_real - y_pred)^2, na.rm = TRUE) / sum((y_real - mean(y_real))^2, na.rm = TRUE),
                              RMSE = sqrt(mean((y_real - y_pred)^2, na.rm = TRUE)),
                              MAE = mean(abs(y_real - y_pred), na.rm = TRUE),
                              MAPE = mean(abs((y_real - y_pred) / y_real), na.rm = TRUE) * 100
                            )
    )
  }

  return(resultados)
}

# Evaluar Prophet por tren
resultados_trenes_prophet <- evaluar_prophet_por_tren()

# Para evaluar Prophet globalmente, necesitamos predecir sobre todos los datos
predecir_prophet_global <- function() {
  predicciones_train <- numeric(nrow(trainData))
  predicciones_test <- numeric(nrow(testData))

  for (i in 1:nrow(trainData)) {
    tren <- trainData$TREN[i]
    fecha <- trainData$Fecha[i]

    pred <- predict(modelos_prophet[[tren]], data.frame(ds = fecha))
    pred_valor <- pred %>% filter(ds == fecha) %>% pull(yhat)

    predicciones_train[i] <- ifelse(length(pred_valor) > 0, pred_valor, NA)
  }

  for (i in 1:nrow(testData)) {
    tren <- testData$TREN[i]
    fecha <- testData$Fecha[i]

    pred <- predict(modelos_prophet[[tren]], data.frame(ds = fecha))
    pred_valor <- pred %>% filter(ds == fecha) %>% pull(yhat)

    predicciones_test[i] <- ifelse(length(pred_valor) > 0, pred_valor, NA)
  }

  return(list(train = predicciones_train, test = predicciones_test))
}


# Obtener predicciones globales de Prophet
pred_prophet_global <- predecir_prophet_global()

# Evaluar y guardar resultados de Prophet
resultados_modelos[["Prophet"]] <- evaluar_modelo(
  pred_prophet_global$train,
  pred_prophet_global$test,
  "Prophet"
)




# ---- COMBINAR RESULTADOS ----

# Combinar resultados por tren de todos los modelos
resultados_trenes_combinados <- bind_rows(
  resultados_trenes_rlm,
  resultados_trenes_xgb,
  resultados_trenes_rf,
  resultados_trenes_prophet
)

# Combinar resultados globales
resultados_globales <- bind_rows(resultados_modelos)

# Mostrar resultados globales
print("Resultados globales de los modelos:")
print(resultados_globales)

# Mostrar resultados por tren
print("Resultados por tren:")
print(resultados_trenes_combinados)

# ---- PREDICCIONES FUTURAS (6 MESES) ----

# Fechas futuras (próximos 6 meses)
fechas_futuras <- seq.Date(from = as.Date("2025-03-01"), by = "month", length.out = 6)

# Función para predecir RLM por tren
predecir_rlm_futuro <- function(tren) {
  # Filtrar datos para este tren
  datos_tren <- BASE_MODELO %>% filter(TREN == tren)

  # Calcular métricas específicas del tren
  disp_90 <- quantile(datos_tren$DISPONIBILIDAD, probs = 0.90, na.rm = TRUE)
  max_horas <- max(datos_tren$HORAS, na.rm = TRUE)
  costo_prom_tren <- mean(datos_tren$Costo_prom_ent, na.rm = TRUE)
  capacidad_nominal <- tail(datos_tren$CAPACIDAD_NOMINAL_MES, 1)

  # Entrenar modelo específico para este tren
  modelo_tren <- lm(KG ~ DISPONIBILIDAD + HORAS + Costo_prom_ent, data = datos_tren)

  # Crear datos futuros
  futuro_datos <- data.frame(
    DISPONIBILIDAD = rep(disp_90, 6),
    HORAS = rep(max_horas, 6),
    Costo_prom_ent = rep(costo_prom_tren, 6)
  )

  # Predecir
  predicciones <- predict(modelo_tren, newdata = futuro_datos)

  # Crear dataframe con predicciones
  predicciones_futuras <- data.frame(
    Fecha = fechas_futuras,
    Prediccion = predicciones,
    Capacidad_Teorica = rep(capacidad_nominal, 6),
    TREN = tren,
    Modelo = "RLM"
  )

  return(predicciones_futuras)
}




# Función para predecir XGBoost por tren
predecir_xgboost_futuro <- function(tren) {
  # Filtrar datos para este tren
  datos_tren <- BASE_MODELO %>% filter(TREN == tren)

  # Calcular métricas específicas del tren
  disp_90 <- quantile(datos_tren$DISPONIBILIDAD, probs = 0.90, na.rm = TRUE)
  max_horas <- max(datos_tren$HORAS, na.rm = TRUE)
  costo_prom_tren <- mean(datos_tren$Costo_prom_ent, na.rm = TRUE)
  capacidad_nominal <- tail(datos_tren$CAPACIDAD_NOMINAL_MES, 1)

  # Crear datos futuros
  futuro_datos <- data.frame(
    DISPONIBILIDAD = rep(disp_90, 6),
    HORAS = rep(max_horas, 6),
    Costo_prom_ent = rep(costo_prom_tren, 6)
  )

  # Convertir a formato XGBoost
  futuro_datos_matrix <- xgb.DMatrix(data = as.matrix(futuro_datos))

  # Predecir
  predicciones <- predict(modelo_xgb, futuro_datos_matrix)

  # Crear dataframe con predicciones
  predicciones_futuras <- data.frame(
    Fecha = fechas_futuras,
    Prediccion = predicciones,
    Capacidad_Teorica = rep(capacidad_nominal, 6),
    TREN = tren,
    Modelo = "XGBoost"
  )

  return(predicciones_futuras)
}




# Función para predecir con RF por tren
predecir_rf_futuro <- function(tren) {
  # Filtrar datos para este tren
  datos_tren <- BASE_MODELO %>% filter(TREN == tren)

  # Verificar si hay datos suficientes para predecir
  if (nrow(datos_tren) < 1) {
    warning(paste("No hay suficientes datos para", tren))
    return(NULL)
  }

  # Seleccionar las variables predictoras (ajusta según tu dataset)
  X_nuevo <- datos_tren %>% select(DISPONIBILIDAD, HORAS, Costo_prom_ent)

  # Predecir con el modelo Random Forest entrenado
  prediccion_rf <- predict(modelo_rf, newdata = X_nuevo)

  # Obtener la última capacidad nominal registrada
  capacidad_nominal <- tail(datos_tren$CAPACIDAD_NOMINAL_MES, 1)

  # Crear dataframe con predicciones futuras
  predicciones_futuras <- data.frame(
    Fecha = fechas_futuras,  # Asegúrate de que `fechas_futuras` está definida
    Prediccion = rep(mean(prediccion_rf, na.rm = TRUE), 6),  # Promedio de predicciones recientes
    Capacidad_Teorica = rep(capacidad_nominal, 6),
    TREN = tren,
    Modelo = "RF"
  )

  return(predicciones_futuras)
}




# Función para predecir Prophet por tren
predecir_prophet_futuro <- function(tren) {
  # Obtener capacidad nominal
  capacidad_nominal <- tail(BASE_MODELO %>%
                              filter(TREN == tren) %>%
                              pull(CAPACIDAD_NOMINAL_MES), 1)

  # Crear futuro dataframe para Prophet
  future <- make_future_dataframe(modelos_prophet[[tren]], periods = 6, freq = "month")

  # Predecir
  forecast <- predict(modelos_prophet[[tren]], future)

  # Filtrar solo las fechas futuras
  forecast_futuro <- forecast %>%
    filter(ds >= as.Date("2025-03-01")) %>%
    head(6)

  # Crear dataframe con predicciones
  predicciones_futuras <- data.frame(
    Fecha = forecast_futuro$ds,
    Prediccion = forecast_futuro$yhat,
    Capacidad_Teorica = rep(capacidad_nominal, 6),
    TREN = tren,
    Modelo = "Prophet"
  )

  return(predicciones_futuras)
}

# Generar predicciones para cada tren y cada modelo
predicciones_finales <- data.frame()

for (tren in trenes_unicos) {
  # RLM
  pred_rlm <- predecir_rlm_futuro(tren)

  # XGBoost
  pred_xgb <- predecir_xgboost_futuro(tren)

  # RF
  pred_rf <- predecir_rf_futuro(tren)

  # Prophet
  pred_prophet <- predecir_prophet_futuro(tren)

  # Combinar
  predicciones_finales <- bind_rows(
    predicciones_finales,
    pred_rlm,
    pred_xgb,
    pred_rf,
    pred_prophet
  )
}

# ---- PREPARAR DATOS PARA GRÁFICOS ----

# Preparar datos históricos
historico <- BASE_MODELO %>%
  select(Fecha, KG, TREN, CAPACIDAD_NOMINAL_MES) %>%
  rename(Historico_KG = KG, Capacidad_Teorica = CAPACIDAD_NOMINAL_MES)

# Crear dataframe para los gráficos de cada modelo
crear_datos_grafico <- function(modelo) {
  # Filtrar predicciones para este modelo
  pred_modelo <- predicciones_finales %>%
    filter(Modelo == modelo) %>%
    rename(Capacidad_Max = Prediccion)

  # Unir con histórico
  datos_completos <- bind_rows(
    # Añadir columna Modelo al histórico
    historico %>% mutate(Modelo = modelo),
    # Seleccionar columnas relevantes de predicciones
    pred_modelo %>% select(Fecha, Capacidad_Max, Capacidad_Teorica, TREN, Modelo)
  )

  return(datos_completos)
}

# Crear dataframes para cada modelo
datos_rlm <- crear_datos_grafico("RLM")
datos_xgb <- crear_datos_grafico("XGBoost")
datos_rf <- crear_datos_grafico("RF")
datos_prophet <- crear_datos_grafico("Prophet")

# ---- VISUALIZACIÓN DE RESULTADOS ----

# Función para crear gráficos por modelo
crear_grafico_modelo <- function(datos, titulo_modelo) {
  ggplot(datos, aes(x = Fecha)) +
    geom_line(aes(y = Historico_KG / 1000, color = "Histórico (MT)"), size = 1, na.rm = TRUE) +
    geom_text(aes(y = Historico_KG / 1000, label = round(Historico_KG / 1000, 1), color = "Histórico (MT)"),
              vjust = -1, size = 2.5, check_overlap = TRUE, na.rm = TRUE) +

    geom_line(aes(y = Capacidad_Max / 1000, color = "Capacidad Máxima (Predicción) (MT)"),
              size = 1, linetype = "dashed", na.rm = TRUE) +
    geom_text(aes(y = Capacidad_Max / 1000, label = round(Capacidad_Max / 1000, 1), color = "Capacidad Máxima (Predicción) (MT)"),
              vjust = -1, size = 2.5, check_overlap = TRUE, na.rm = TRUE) +

    geom_line(aes(y = Capacidad_Teorica / 1000, color = "Capacidad Teórica (Nominal) (MT)"),
              size = 1, linetype = "dotted", na.rm = TRUE) +
    geom_text(aes(y = Capacidad_Teorica / 1000, label = round(Capacidad_Teorica / 1000, 1), color = "Capacidad Teórica (Nominal) (MT)"),
              vjust = -1, size = 2.5, check_overlap = TRUE, na.rm = TRUE) +

    facet_wrap(~ TREN, scales = "free_y") +
    scale_y_continuous(labels = label_number(suffix = " MT", accuracy = 1)) +
    labs(title = paste("Histórico vs Predicción vs Capacidad Teórica por TREN -", titulo_modelo),
         x = "Fecha",
         y = "Capacidad en Toneladas (MT)",
         color = "Leyenda") +
    theme_minimal() +
    theme(legend.position = "bottom")
}

  # Crear los gráficos
  grafico_rlm <- crear_grafico_modelo(datos_rlm, "Modelo RLM")
  grafico_xgb <- crear_grafico_modelo(datos_xgb, "Modelo XGBoost")
  grafico_rf <- crear_grafico_modelo(datos_rf, "Modelo RF")
  grafico_prophet <- crear_grafico_modelo(datos_prophet, "Modelo Prophet")

  # Mostrar gráficos
  print(grafico_rlm)
  print(grafico_xgb)
  print(grafico_rf)
  print(grafico_prophet)


"GRAFICO COMPARATIVO 4 MODELOS"
library(ggplot2)
library(scales)
library(dplyr)

# Convertir los datos a toneladas
datos_combinados <- datos_rlm %>%
  select(Fecha, TREN, Historico_KG, Capacidad_Teorica) %>%
  left_join(datos_rlm %>% select(Fecha, TREN, Pred_RLM = Capacidad_Max), by = c("Fecha", "TREN")) %>%
  left_join(datos_xgb %>% select(Fecha, TREN, Pred_XGB = Capacidad_Max), by = c("Fecha", "TREN")) %>%
  left_join(datos_rf %>% select(Fecha, TREN, Pred_RF = Capacidad_Max), by = c("Fecha", "TREN")) %>%
  left_join(datos_prophet %>% select(Fecha, TREN, Pred_Prophet = Capacidad_Max), by = c("Fecha", "TREN")) %>%
  mutate(across(c(Historico_KG, Capacidad_Teorica, Pred_RLM, Pred_XGB, Pred_RF, Pred_Prophet), ~ .x / 1000))  # De KG a Toneladas

# Crear gráfico con etiquetas
ggplot(datos_combinados, aes(x = Fecha)) +
  geom_line(aes(y = Historico_KG, color = "Histórico KG"), size = 1, na.rm = TRUE) +
  geom_text(aes(y = Historico_KG, label = round(Historico_KG, 0), color = "Histórico KG"),
            vjust = -0.8, size = 2.8, show.legend = FALSE, na.rm = TRUE) +

  geom_line(aes(y = Pred_RLM, color = "Predicción RLM"), size = 1, linetype = "solid", na.rm = TRUE) +
  geom_text(aes(y = Pred_RLM, label = round(Pred_RLM, 0), color = "Predicción RLM"),
            vjust = -0.8, size = 2.8, show.legend = FALSE, na.rm = TRUE) +

  geom_line(aes(y = Pred_XGB, color = "Predicción XGBoost"), size = 1, linetype = "solid", na.rm = TRUE) +
  geom_text(aes(y = Pred_XGB, label = round(Pred_XGB, 0), color = "Predicción XGBoost"),
            vjust = -0.8, size = 2.8, show.legend = FALSE, na.rm = TRUE) +

  geom_line(aes(y = Pred_RF, color = "Predicción RF"), size = 1, linetype = "solid", na.rm = TRUE) +
  geom_text(aes(y = Pred_RF, label = round(Pred_RF, 0), color = "Predicción RF"),
            vjust = -0.8, size = 2.8, show.legend = FALSE, na.rm = TRUE) +

  geom_line(aes(y = Pred_Prophet, color = "Predicción Prophet"), size = 1, linetype = "solid", na.rm = TRUE) +
  geom_text(aes(y = Pred_Prophet, label = round(Pred_Prophet, 0), color = "Predicción Prophet"),
            vjust = -0.8, size = 2.8, show.legend = FALSE, na.rm = TRUE) +

  facet_wrap(~ TREN, scales = "free_y") +
  scale_y_continuous(labels = comma_format(suffix = " MT")) +  # Mostrar en toneladas (MT)
  labs(title = "Gráfico Comparativo 4 Modelos vs. Histórico por TREN",
       x = "Fecha",
       y = "Capacidad en Toneladas (MT)",
       color = "Leyenda") +
  theme_minimal() +
  theme(legend.position = "bottom")



# ---- GRÁFICOS COMPARATIVOS ----
# R2
graf_r2 <- ggplot(resultados_trenes_combinados, aes(x = TREN, y = R2, fill = Modelo)) +
  geom_bar(stat = "identity", position = "dodge") +
  geom_text(aes(label = round(R2, 2)),
            position = position_dodge(0.9),
            vjust = 1.5,
            size = 3.5,
            color = "white") +
  labs(title = "Comparación de R² por Tren y Modelo",
       x = "Tren Productivo",
       y = "R²") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  coord_cartesian(ylim = c(-1, 1))   # <<<<<< CORTE DEL EJE Y

# RMSE
graf_rmse <- ggplot(resultados_trenes_combinados, aes(x = TREN, y = RMSE, fill = Modelo)) +
  geom_bar(stat = "identity", position = "dodge") +
  geom_text(aes(label = round(RMSE, 0)),
            position = position_dodge(0.9),
            vjust = 1.5,
            color = "white",
            size = 3.5) +
  labs(title = "Comparación de RMSE", x = "TREN", y = "RMSE") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# MAE
graf_mae <- ggplot(resultados_trenes_combinados, aes(x = TREN, y = MAE, fill = Modelo)) +
  geom_bar(stat = "identity", position = "dodge") +
  geom_text(aes(label = round(MAE, 0)),
            position = position_dodge(0.9),
            vjust = 1.5,
            color = "white",
            size = 3.5) +
  labs(title = "Comparación de MAE", x = "TREN", y = "MAE") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# MAPE
graf_mape <- ggplot(resultados_trenes_combinados, aes(x = TREN, y = MAPE, fill = Modelo)) +
  geom_bar(stat = "identity", position = "dodge") +
  geom_text(aes(label = paste0(round(MAPE, 1), "%")),
            position = position_dodge(0.9),
            vjust = 1.5,
            color = "white",
            size = 3.5) +
  labs(title = "Comparación de MAPE", x = "TREN", y = "MAPE (%)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



# Combinar todos los gráficos con patchwork
library(patchwork)
figura_comparativa_modelos <- (graf_r2 | graf_rmse) / (graf_mae | graf_mape)

# Mostrar la figura
print(figura_comparativa_modelos)

# Tabla global en forma visual
tabla_plot <- ggplot() +
  theme_void() +
  annotation_custom(tableGrob(resultados_globales), xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
  ggtitle("Comparación de métricas entre modelos")

# Mostrar tabla como imagen en ggplot
print(tabla_plot)

# Unir todos los resultados en una estructura
resultados_completos <- list(
  metricas_globales = resultados_globales,
  metricas_por_tren = resultados_trenes_combinados,
  predicciones = predicciones_finales,
  graficos = list(
    comparativos = figura_comparativa_modelos,
    tabla_metricas = tabla_plot
  )
)

# Guardar resultados en un archivo RDS
saveRDS(resultados_completos, "resultados_4_modelos.rds")

# Para cargar después:
# resultados <- readRDS("resultados_4_modelos.rds")

# Mostrar tabla Markdown si estás en RMarkdown o consola
knitr::kable(resultados_globales,
             caption = "Comparación de métricas entre modelos",
             format = "markdown")






    "GRAFICA PLAN VS KG VS CAPACIDAD"
    library(ggplot2)
    library(dplyr)
    library(scales)

    # Diccionario de meses en español
    meses_dict <- c("Enero" = "01", "Febrero" = "02", "Marzo" = "03", "Abril" = "04",
                    "Mayo" = "05", "Junio" = "06", "Julio" = "07", "Agosto" = "08",
                    "Septiembre" = "09", "Octubre" = "10", "Noviembre" = "11", "Diciembre" = "12")

    # Filtrar y transformar PLAN_PROTECNICA
    PLAN_FILTRADO <- PLAN_PROTECNICA %>%
      filter(PLANTA %in% c("P1A", "P1B")) %>%
      mutate(
        AÑO = as.numeric(trimws(AÑO)),  # Convertir AÑO a número
        MES = meses_dict[trimws(MES)],  # Mapear MES al número correspondiente
        Fecha = as.Date(paste(AÑO, MES, "01", sep = "-"))  # Crear la fecha
      ) %>%
      filter(Fecha >= as.Date("2024-04-01")) %>%  # 🔹 Filtrar desde abril 2024
      group_by(Fecha) %>%
      summarise(Plan_KG = sum(`Kg programados`, na.rm = TRUE))

    # Agrupar la base modelo por fecha
    BASE_AGREGADA <- BASE_MODELO %>%
      mutate(Fecha = as.Date(Fecha)) %>%  # Asegurar que Fecha sea de tipo Date
      filter(Fecha >= as.Date("2024-05-01")) %>%  # 🔹 Filtrar desde mayo 2024
      group_by(Fecha) %>%
      summarise(
        Total_KG = sum(KG, na.rm = TRUE),
        Total_Capacidad_Teorica = sum(CAPACIDAD_NOMINAL_MES, na.rm = TRUE)
      )

    # Unir con los datos de planificación
    BASE_FINAL <- BASE_AGREGADA %>%
      left_join(PLAN_FILTRADO, by = "Fecha") %>%
      mutate(
        Plan_KG = replace_na(Plan_KG, 0),  # Reemplazar NA con 0 en Plan KG
        Cumplimiento = ifelse(Plan_KG > 0, (Total_KG / Plan_KG) * 100, NA)  # Calcular % de cumplimiento
      )

    library(ggplot2)
    library(dplyr)
    library(scales)

    # Crear el gráfico con líneas y etiquetas de valores reales
    ggplot(BASE_FINAL, aes(x = Fecha)) +
      geom_line(aes(y = Total_KG, color = "Histórico KG"), size = 1, na.rm = TRUE) +
      geom_point(aes(y = Total_KG, color = "Histórico KG"), size = 2, na.rm = TRUE) +
      geom_text(aes(y = Total_KG, label = scales::comma(Total_KG, accuracy = 1), color = "Histórico KG"),
                vjust = -1, size = 3, check_overlap = TRUE, na.rm = TRUE) +

      geom_line(aes(y = Plan_KG, color = "Plan KG"), size = 1, linetype = "dashed", na.rm = TRUE) +
      geom_point(aes(y = Plan_KG, color = "Plan KG"), size = 2, na.rm = TRUE) +
      geom_text(aes(y = Plan_KG, label = scales::comma(Plan_KG, accuracy = 1), color = "Plan KG"),
                vjust = -1, size = 3, check_overlap = TRUE, na.rm = TRUE) +

      geom_line(aes(y = Total_Capacidad_Teorica, color = "Capacidad Teórica"), size = 1, linetype = "dotted", na.rm = TRUE) +
      geom_point(aes(y = Total_Capacidad_Teorica, color = "Capacidad Teórica"), size = 2, na.rm = TRUE) +
      geom_text(aes(y = Total_Capacidad_Teorica, label = scales::comma(Total_Capacidad_Teorica, accuracy = 1), color = "Capacidad Teórica"),
                vjust = -1, size = 3, check_overlap = TRUE, na.rm = TRUE) +

      scale_y_continuous(labels = comma) +
      labs(title = "Histórico de Producción vs. Plan de Producción vs. Capacidad Teórica",
           x = "Fecha",
           y = "Capacidad en KG",
           color = "Leyenda") +
      theme_minimal() +
      theme(legend.position = "bottom")



#Boxplot de errores absolutos por modelo y tren


    # Construir base para errores
    errores_absolutos_df <- bind_rows(
      testData %>%
        mutate(Error_Absoluto = abs(KG - pred_test_lm),
               Modelo = "RLM"),
      testData %>%
        mutate(Error_Absoluto = abs(KG - pred_test_xgb),
               Modelo = "XGBoost"),
      testData %>%
        mutate(Error_Absoluto = abs(KG - pred_test_rf),
               Modelo = "RF")
    )

    library(ggplot2)

    ggplot(errores_absolutos_df, aes(x = Modelo, y = Error_Absoluto, fill = Modelo)) +
      geom_boxplot(outlier.shape = NA) +
      facet_wrap(~ TREN, scales = "free_y") +
      labs(title = "Boxplot de errores absolutos por modelo y tren",
           x = "Modelo",
           y = "Error Absoluto (KG)") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      scale_y_continuous(labels = scales::comma)








    library(dplyr)
    library(tidyr)
    library(ggplot2)
    library(scales)

    # 1. Encontrar el mejor modelo por tren (mayor R2)
    mejor_modelo_por_tren <- resultados_trenes_combinados %>%
      filter(Modelo != "Prophet") %>%  # 🔵 Excluir Prophet
      group_by(TREN) %>%
      filter(R2 == max(R2, na.rm = TRUE)) %>%
      select(TREN, Modelo)

    print(mejor_modelo_por_tren)

    # 2. Juntar todas las predicciones históricas
    predicciones_rlm <- datos_rlm %>% select(Fecha, TREN, Prediccion = Capacidad_Max) %>% mutate(Modelo = "RLM")
    predicciones_xgb <- datos_xgb %>% select(Fecha, TREN, Prediccion = Capacidad_Max) %>% mutate(Modelo = "XGBoost")
    predicciones_rf <- datos_sma %>% select(Fecha, TREN, Prediccion = Capacidad_Max) %>% mutate(Modelo = "RF")
    predicciones_prophet <- datos_prophet %>% select(Fecha, TREN, Prediccion = Capacidad_Max) %>% mutate(Modelo = "Prophet")

    # Unir todas las predicciones
    predicciones_todas <- bind_rows(predicciones_rlm, predicciones_xgb, predicciones_rf, predicciones_prophet) %>%
      mutate(Prediccion_MT = Prediccion / 1000)  # De KG a toneladas

    # 3. Seleccionar predicción del mejor modelo por tren
    predicciones_mejor_modelo <- predicciones_todas %>%
      inner_join(mejor_modelo_por_tren, by = c("TREN", "Modelo"))

    # 4. Resumir proyecciones promedio por tren
    resumen_proyecciones <- predicciones_mejor_modelo %>%
      group_by(TREN, Modelo) %>%
      summarise(
        Capacidad_Proyectada_MT = mean(Prediccion_MT, na.rm = TRUE),
        .groups = "drop"
      )

    # 5. Resumir capacidad teórica
    resumen_teorico <- BASE_MODELO %>%
      group_by(TREN) %>%
      summarise(
        Capacidad_Teorica_MT = mean(CAPACIDAD_NOMINAL_MES, na.rm = TRUE) / 1000
      )

    # 6. Unir todo y calcular el % de Gap
    tabla_capacidades <- resumen_teorico %>%
      left_join(resumen_proyecciones, by = "TREN") %>%
      mutate(
        Gap_Porcentaje = round(((Capacidad_Teorica_MT - Capacidad_Proyectada_MT) / Capacidad_Teorica_MT) * 100, 1)
      )

    # Mostrar tabla
    print(tabla_capacidades)

    tabla_capacidades %>%
      mutate(Gap_Porcentaje = paste0(Gap_Porcentaje, "%"))
    library(kableExtra)
    library(knitr)
    # 1. Asegurarte de tener Gap como texto con porcentaje
    tabla_capacidades_final <- tabla_capacidades %>%
      mutate(Gap_Porcentaje = paste0(Gap_Porcentaje, "%"))

    # 2. Hacer la tabla bonita
    tabla_capacidades_final %>%
      select(TREN, Capacidad_Teorica_MT, Capacidad_Proyectada_MT, Modelo, Gap_Porcentaje) %>%
      kable(
        caption = "Tabla 3. Resumen de Capacidad Teórica vs Capacidad Proyectada por Tren",
        col.names = c("Tren Productivo", "Capacidad Teórica (MT)", "Capacidad Proyectada (MT)", "Modelo Escogido", "Gap (%)"),
        align = "c"
      ) %>%
      kable_styling(full_width = FALSE, position = "center", font_size = 12, bootstrap_options = c("striped", "hover", "condensed"))




    # 7. Preparar tabla larga para gráfico
    tabla_larga <- tabla_capacidades %>%
      pivot_longer(cols = c(Capacidad_Teorica_MT, Capacidad_Proyectada_MT),
                   names_to = "Tipo_Capacidad",
                   values_to = "Toneladas")

    # 8. Crear gráfico
    ggplot(tabla_larga, aes(x = TREN, y = Toneladas, fill = Tipo_Capacidad)) +
      geom_bar(stat = "identity", position = position_dodge(width = 0.7), width = 0.6) +
      geom_text(aes(label = round(Toneladas, 1)),
                position = position_dodge(width = 0.7),
                vjust = -0.5, size = 3) +
      facet_wrap(~ Modelo) +  # Mostrando el modelo ganador por tren
      scale_y_continuous(labels = comma_format(suffix = " MT")) +
      scale_fill_manual(values = c("Capacidad_Teorica_MT" = "#1f77b4",
                                   "Capacidad_Proyectada_MT" = "#ff7f0e"),
                        labels = c("Capacidad Teórica", "Capacidad Proyectada")) +
      labs(title = "Figura 24. Capacidad Teórica vs Capacidad Proyectada por Tren",
           x = "Tren Productivo",
           y = "Capacidad (Toneladas - MT)",
           fill = "Tipo de Capacidad") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            legend.position = "bottom")









    #EXPORTAR DATASET BI

    # Guardar BASE_MODELO para Power BI
    write_xlsx(BASE_MODELO, "C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/BASE_MODELO_EXPORT.xlsx")

    # Guardar predicciones
    write_xlsx(predicciones_finales, "C:/Users/PIPE DUARTE/Desktop/Maestria Ciencia de Datos/Proyecto de Grado/DB/PREDICCIONES_MODELOS_EXPORT.xlsx")

