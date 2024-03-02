# Esse script faz a limpeza da base gerada pela IA e complementa
# suas informações

desembargadores_gpt <- arrow::read_parquet(
  here::here("desembargadores/parquet/desembargadores.parquet")
)

# informações complementares extraídas do PDF por regex

texto <- pdftools::pdf_text(
  "https://www.tjsp.jus.br/Download/Portal/Biblioteca/Biblioteca/Curriculum/Curriculum.pdf"
)

infos_pdf_desembargadores <- texto |>
  tibble::enframe() |>
  dplyr::mutate(sexo = stringr::str_extract(value, "Nascid[oa]|Bacharel ")) |>
  dplyr::filter(!is.na(sexo)) |>
  dplyr::mutate(
    sexo = dplyr::if_else(sexo %in% c("Nascido", "Bacharel "), "M", "F"),
    apostila = stringr::str_detect(value, "apostila"),
    aposentou = stringr::str_detect(value, "Aposent"),
    faleceu = stringr::str_detect(value, "[fF]alec")
  ) |>
  dplyr::select(page = name, sexo, apostila, aposentou, faleceu)

# limpeza dos municípios e outras informações dos desembargadores
da_desembargadores_1990 <- desembargadores_gpt |>
  tibble::rowid_to_column() |>
  dplyr::mutate(nome = stringr::str_to_upper(nome)) |>
  dplyr::filter(nome != "NA") |>
  # Para esta análise, consideramos somente os desembargadores que foram
  # promovidos a partir de 1990
  dplyr::filter(
    data_promocao_desembargador != "NA",
    data_promocao_desembargador >= "1990-01-01"
  ) |>
  # ajustes nos nomes dos municípios
  munifacil::limpar_colunas(municipio_nascimento, estado_nascimento) |>
  dplyr::mutate(
    uf_join = dplyr::case_when(
      uf_join == "SÃO PAULO" ~ "SP",
      uf_join == "RIO DE JANEIRO" ~ "RJ",
      uf_join == "MINAS GERAIS" ~ "MG",
      uf_join == "PARANÁ" ~ "PR",
      uf_join == "RIO GRANDE DO SUL" ~ "RS",
      uf_join == "BAHIA" ~ "BA",
      uf_join == "PERNAMBUCO" ~ "PE",
      uf_join == "CEARÁ" ~ "CE",
      uf_join == "PARÁ" ~ "PA",
      uf_join == "SANTA CATARINA" ~ "SC",
      uf_join == "GOIÁS" ~ "GO",
      uf_join == "ESPÍRITO SANTO" ~ "ES",
      uf_join == "MARANHÃO" ~ "MA",
      uf_join == "MATO GROSSO" ~ "MT",
      uf_join == "MATO GROSSO DO SUL" ~ "MS",
      uf_join == "PARAÍBA" ~ "PB",
      uf_join == "RIO GRANDE DO NORTE" ~ "RN",
      uf_join == "ALAGOAS" ~ "AL",
      uf_join == "PIAUÍ" ~ "PI",
      uf_join == "AMAZONAS" ~ "AM",
      uf_join == "DISTRITO FEDERAL" ~ "DF",
      uf_join == "SERGIPE" ~ "SE",
      uf_join == "RONDÔNIA" ~ "RO",
      uf_join == "TOCANTINS" ~ "TO",
      uf_join == "ACRE" ~ "AC",
      uf_join == "RORAIMA" ~ "RR",
      uf_join == "CAPITAL FEDERAL" ~ "RJ",
      .default = uf_join
    ),
    muni_join = dplyr::case_when(
      muni_join == "santo s" ~ "santos",
      muni_join == "ipaucu" ~ "ipaussu",
      muni_join == "goiana" ~ "goiania",
      muni_join == "sao luiz" ~ "sao luis",
      muni_join == "sucuru" ~ "serra branca",
      muni_join == "laranjal" ~ "laranjal paulista",
      muni_join == "sao raimundo" ~ "sao raimundo nonato",
      muni_join == "engenheiro balduino" ~ "monte aprazivel",
      muni_join == "pinhal" ~ "espirito santo do pinhal",
      .default = muni_join
    )
  ) |>
  munifacil::incluir_codigo_ibge() |>
  dplyr::mutate(
    juiz_substituto_2grau = dplyr::case_when(
      juiz_substituto_2grau == "sim" ~ "sim",
      juiz_substituto_2grau == "não" ~ "não",
      juiz_substituto_2grau == "não" ~ "não",
      juiz_substituto_2grau == "NA" ~ "não"
    ),
    foi_promotor = dplyr::case_when(
      foi_promotor == "sim" ~ "sim",
      foi_promotor == "não" ~ "não",
      foi_promotor == "não" ~ "não",
      foi_promotor == "NA" ~ "não"
    ),
    quinto_constitucional = dplyr::case_when(
      quinto_constitucional == "sim" ~ "sim",
      quinto_constitucional == "não" ~ "não",
      quinto_constitucional == "não" ~ "não",
      quinto_constitucional == "NA" ~ "não"
    )
  )

# Lista de desembargadores aposentados que foram coletados manualmente,
# já que o arquivo PDF original não continha essa informação
aposentados <- c(
  "EVERALDO DE MELO COLOMBI",
  "FRANCISCO ANTONIO CASCONI",
  "JOSÉ BENEDITO FRANCO DE GODOI",
  "JOSÉ TARCISO BERALDO",
  "MARIO ANTONIO SILVEIRA",
  "VIRGILIO DE OLIVEIRA JÚNIOR",
  "GILBERTO DE CARVALHO DINIZ JUNQUEIRA"
)

# Na base de desembargadores arivos, retiramos os que já se aposentaram
da_desembargadores_ativos <- da_desembargadores_1990 |>
  dplyr::filter(
    data_nascimento != "NA",
    data_aposentadoria == "NA",
    data_falecimento == "NA",
    #!rowid %in% c("78", "954"),
    !nome %in% aposentados
  )

# Agora, vamos exportar para vários formatos

## Parquet
# Informações dos desembargadores ativos
arrow::write_parquet(
  da_desembargadores_ativos,
  here::here("desembargadores/parquet/desembargadores_ativos.parquet")
)
# informações do PDF
arrow::write_parquet(
  infos_pdf_desembargadores,
  here::here("desembargadores/parquet/desembargadores_infos_pdf.parquet")
)
# Informações dos desembargadores desde 1990
arrow::write_parquet(
  da_desembargadores_1990,
  here::here("desembargadores/parquet/desembargadores_1990.parquet")
)
## CSV
# Informações dos desembargadores ativos
readr::write_csv(
  da_desembargadores_ativos,
  here::here("desembargadores/csv/desembargadores_ativos.csv")
)
# informações do PDF
readr::write_csv(
  infos_pdf_desembargadores,
  here::here("desembargadores/csv/desembargadores_infos_pdf.csv")
)
# Informações dos desembargadores desde 1990
readr::write_csv(
  da_desembargadores_1990,
  here::here("desembargadores/csv/desembargadores_1990.csv")
)
# Base do GPT
readr::write_csv(
  desembargadores_gpt,
  here::here("desembargadores/csv/desembargadores_gpt.csv")
)

## XLSX
# Informações dos desembargadores ativos
writexl::write_xlsx(
  da_desembargadores_ativos,
  here::here("desembargadores/xlsx/desembargadores_ativos.xlsx")
)
# informações do PDF
writexl::write_xlsx(
  infos_pdf_desembargadores,
  here::here("desembargadores/xlsx/desembargadores_infos_pdf.xlsx")
)
# Informações dos desembargadores desde 1990
writexl::write_xlsx(
  da_desembargadores_1990,
  here::here("desembargadores/xlsx/desembargadores_1990.xlsx")
)
# Base do GPT
writexl::write_xlsx(
  desembargadores_gpt,
  here::here("desembargadores/xlsx/desembargadores_gpt.xlsx")
)

# Em seguida, vamos para o arquivo 03-analises.qmd
