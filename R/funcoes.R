# Leitura, validação, métricas e gráficos do painel de seguidores.

library(dplyr)
library(plotly)
library(htmltools)

# ---- Configuração -----------------------------------------------------------

DATA_ELEICAO <- as.Date("2026-10-25")
FUSO <- "America/Fortaleza"
MESES <- c("jan", "fev", "mar", "abr", "mai", "jun",
           "jul", "ago", "set", "out", "nov", "dez")

# Tinta e superfícies (cores de dados vêm de data/candidatos.csv)
TINTA <- "#0b0b0b"
TINTA_2 <- "#52514e"
TINTA_MUDA <- "#898781"
GRADE <- "#e1e0d9"
EIXO <- "#c3c2b7"
SUPERFICIE <- "#ffffff"

# ---- Leitura e validação ----------------------------------------------------

ler_candidatos <- function(arquivo = "data/candidatos.csv") {
  read.csv(arquivo, colClasses = "character", fileEncoding = "UTF-8")
}

ler_eventos <- function(arquivo = "data/eventos.csv") {
  ev <- read.csv(arquivo, colClasses = "character", fileEncoding = "UTF-8")
  ev$data <- as.Date(ev$data)
  ev[!is.na(ev$data), ]
}

# Uma linha por rede social: id, nome exibido e planilha da coleta
ler_redes <- function(arquivo = "data/redes.csv") {
  read.csv(arquivo, colClasses = "character", fileEncoding = "UTF-8")
}

# ---- Células da planilha ----------------------------------------------------
# A planilha é lida célula a célula (col_types = "list") para aceitar tanto
# datas e números do Excel quanto texto digitado ("16/10/2026", "151.340").

celula_vazia <- function(v) {
  length(v) == 0 || is.na(v[1]) || trimws(as.character(v[1])) == ""
}

# Data do Excel, número de série ou texto AAAA-MM-DD / DD/MM/AAAA
para_data <- function(v) {
  if (celula_vazia(v)) return(as.Date(NA))
  if (inherits(v, c("POSIXct", "Date"))) return(as.Date(format(v, "%Y-%m-%d", tz = "UTC")))
  if (is.numeric(v)) return(as.Date(v, origin = "1899-12-30"))
  txt <- trimws(as.character(v))
  d <- as.Date(txt, format = "%Y-%m-%d")
  if (is.na(d)) d <- as.Date(txt, format = "%d/%m/%Y")
  # descarta anos implausíveis (ex.: "16-10-26" lido como ano 0016)
  if (!is.na(d) && !format(d, "%Y") %in% as.character(2020:2100)) d <- as.Date(NA)
  d
}

# Número inteiro não negativo; NA se vazia, NaN se inválida
para_numero <- function(v) {
  if (celula_vazia(v)) return(NA_real_)
  if (is.numeric(v)) return(if (v >= 0 && v == round(v)) as.numeric(v) else NaN)
  txt <- trimws(as.character(v))
  if (!grepl("^[0-9. ]+$", txt)) return(NaN)
  as.numeric(gsub("[. ]", "", txt))
}

# Lê a planilha de uma rede (uma linha por dia, uma coluna por candidato) e
# devolve o formato longo. Interrompe a renderização com uma mensagem clara
# se houver erro de digitação, para o site nunca publicar dados quebrados.
ler_seguidores <- function(arquivo, candidatos) {
  nome <- basename(arquivo)
  bruto <- readxl::read_excel(arquivo, sheet = 1, col_types = "list",
                              .name_repair = "minimal")
  names(bruto) <- tolower(trimws(names(bruto)))

  if (!"data" %in% names(bruto)) {
    stop("A planilha '", nome, "' precisa de uma coluna 'data'.", call. = FALSE)
  }
  ausentes <- setdiff(candidatos$id, names(bruto))
  if (length(ausentes)) {
    stop("Coluna(s) ausente(s) na planilha '", nome, "': ",
         paste(ausentes, collapse = ", "), call. = FALSE)
  }

  linha <- seq_len(nrow(bruto)) + 1
  vazia <- vapply(bruto$data, celula_vazia, logical(1))
  bruto <- bruto[!vazia, , drop = FALSE]
  linha <- linha[!vazia]

  datas <- do.call(c, c(list(as.Date(character())), lapply(bruto$data, para_data)))
  if (anyNA(datas)) {
    stop("Data inválida na planilha '", nome, "', linha(s) ",
         paste(linha[is.na(datas)], collapse = ", "),
         ". Use uma data do Excel ou o formato DD/MM/AAAA.", call. = FALSE)
  }
  if (anyDuplicated(datas)) {
    stop("Data repetida na planilha '", nome, "': ",
         paste(unique(format(datas[duplicated(datas)], "%d/%m/%Y")), collapse = ", "),
         call. = FALSE)
  }

  partes <- lapply(candidatos$id, function(id) {
    valor <- vapply(bruto[[id]], para_numero, numeric(1))
    invalido <- is.nan(valor)
    if (any(invalido)) {
      stop("Valor inválido na coluna '", id, "' da planilha '", nome, "', linha(s) ",
           paste(linha[invalido], collapse = ", "),
           ". Use apenas números inteiros (ex.: 150953).", call. = FALSE)
    }
    data.frame(data = datas, candidato = id, seguidores = valor)
  })

  bind_rows(partes) |>
    filter(!is.na(seguidores)) |>
    arrange(candidato, data)
}

# Tudo o que uma página de rede precisa
carregar_rede <- function(rede, candidatos) {
  long <- ler_seguidores(rede$arquivo, candidatos)
  if (!nrow(long)) {
    stop("A planilha '", basename(rede$arquivo), "' não tem nenhuma coleta.", call. = FALSE)
  }
  diario <- calcular_diario(long)
  list(
    nome = rede$nome,
    long = long,
    diario = diario,
    semanal = calcular_semanal(diario),
    resumo = resumir(diario, candidatos),
    diferenca = calcular_diferenca(long, candidatos)
  )
}

# ---- Métricas ---------------------------------------------------------------

# Saldo entre coletas. Se um dia ficar sem coleta, `saldo_dia` divide o saldo
# pelo número de dias do intervalo, para não criar picos falsos.
calcular_diario <- function(long) {
  long |>
    group_by(candidato) |>
    arrange(data, .by_group = TRUE) |>
    mutate(
      dias = as.numeric(data - lag(data)),
      saldo = seguidores - lag(seguidores),
      saldo_dia = saldo / dias,
      saldo_pct_dia = saldo / lag(seguidores) * 100 / dias,
      acumulado = seguidores - first(seguidores),
      acumulado_pct = (seguidores / first(seguidores) - 1) * 100
    ) |>
    ungroup()
}

inicio_semana <- function(d) d - (as.integer(format(d, "%u")) - 1)

# Saldo por semana de calendário (segunda a domingo). Cada intervalo entre
# coletas conta na semana em que termina.
calcular_semanal <- function(diario) {
  diario |>
    filter(!is.na(saldo)) |>
    mutate(semana = inicio_semana(data)) |>
    group_by(candidato, semana) |>
    summarise(saldo = sum(saldo), dias = sum(dias), .groups = "drop")
}

resumir <- function(diario, candidatos) {
  r <- diario |>
    group_by(candidato) |>
    arrange(data, .by_group = TRUE) |>
    summarise(
      n_coletas = n(),
      data_inicial = first(data),
      inicial = first(seguidores),
      data_atual = last(data),
      atual = last(seguidores),
      dias_total = as.numeric(last(data) - first(data)),
      ganho_total = last(seguidores) - first(seguidores),
      ganho_pct = (last(seguidores) / first(seguidores) - 1) * 100,
      ultimo_saldo = last(saldo_dia),
      ultimo_dias = last(dias),
      saldo_7d = if (n() > 1) sum(saldo[data > last(data) - 7], na.rm = TRUE) else NA_real_,
      dias_7d = if (n() > 1) sum(dias[data > last(data) - 7], na.rm = TRUE) else NA_real_,
      mediana_dia = if (n() > 1) median(saldo_dia, na.rm = TRUE) else NA_real_,
      dp_dia = if (n() > 2) sd(saldo_dia, na.rm = TRUE) else NA_real_,
      maior = if (n() > 1) max(saldo_dia, na.rm = TRUE) else NA_real_,
      data_maior = if (n() > 1) data[which.max(saldo_dia)] else as.Date(NA),
      menor = if (n() > 1) min(saldo_dia, na.rm = TRUE) else NA_real_,
      data_menor = if (n() > 1) data[which.min(saldo_dia)] else as.Date(NA),
      .groups = "drop"
    ) |>
    mutate(
      media_dia = ifelse(dias_total > 0, ganho_total / dias_total, NA_real_),
      media_pct_dia = ifelse(dias_total > 0,
                             ((atual / inicial)^(1 / dias_total) - 1) * 100, NA_real_),
      dias_restantes = pmax(as.numeric(DATA_ELEICAO - data_atual), 0),
      projecao = ifelse(is.na(media_dia), NA_real_, atual + media_dia * dias_restantes)
    )
  # mantém a ordem de data/candidatos.csv
  r[match(candidatos$id, r$candidato), ]
}

# Diferença entre os dois candidatos nas datas em que ambos têm coleta
calcular_diferenca <- function(long, candidatos) {
  a <- candidatos$id[1]
  b <- candidatos$id[2]
  long |>
    filter(candidato %in% c(a, b)) |>
    tidyr::pivot_wider(names_from = candidato, values_from = seguidores) |>
    filter(!is.na(.data[[a]]), !is.na(.data[[b]])) |>
    arrange(data) |>
    mutate(diferenca = .data[[b]] - .data[[a]])
}

# ---- Formatação -------------------------------------------------------------

fmt_num <- function(x, digitos = 0, sinal = FALSE) {
  out <- formatC(abs(x), format = "f", digits = digitos,
                 big.mark = ".", decimal.mark = ",")
  prefixo <- ifelse(x < 0, "−", ifelse(sinal & x > 0, "+", ""))
  out <- paste0(prefixo, out)
  out[is.na(x)] <- "–"
  out
}

fmt_pct <- function(x, digitos = 2, sinal = TRUE) {
  out <- paste0(fmt_num(x, digitos, sinal), "%")
  out[is.na(x)] <- "–"
  out
}

fmt_data <- function(d, ano = FALSE) {
  out <- paste0(format(d, "%d"), "/", MESES[as.integer(format(d, "%m"))])
  if (ano) out <- paste0(out, "/", format(d, "%Y"))
  out[is.na(d)] <- "–"
  out
}

fmt_semana <- function(inicio) {
  fim <- inicio + 6
  ifelse(format(inicio, "%m") == format(fim, "%m"),
         paste0(format(inicio, "%d"), "–", fmt_data(fim)),
         paste0(fmt_data(inicio), "–", fmt_data(fim)))
}

# ---- Componentes HTML -------------------------------------------------------

aguardando <- function(texto = "Aguardando a 2ª coleta para calcular os saldos.") {
  div(class = "aguardando", texto)
}

foto_uri <- function(caminho) knitr::image_uri(caminho)

estatistica <- function(rotulo, valor, nota = NULL) {
  div(class = "cand-stat",
      div(class = "cand-stat-rot", rotulo),
      div(class = "cand-stat-val", valor),
      if (!is.null(nota)) div(class = "cand-stat-nota", nota))
}

nota_intervalo <- function(dias) {
  if (is.na(dias) || dias <= 1) NULL else paste0("média de ", dias, " dias")
}

card_candidato <- function(cand, r, rede) {
  div(
    class = "cand-card", style = paste0("--cor:", cand$cor),
    div(class = "cand-topo",
        img(src = foto_uri(cand$foto), alt = paste("Foto de", cand$nome_urna),
            class = "cand-foto"),
        div(div(class = "cand-nome", cand$nome_urna),
            div(class = "cand-partido", paste(cand$partido, "·", cand$numero)))),
    div(class = "cand-hero", fmt_num(r$atual)),
    div(class = "cand-hero-rot",
        paste0("seguidores no ", rede, " em ", fmt_data(r$data_atual))),
    div(class = "cand-stats",
        estatistica("Saldo do dia", fmt_num(r$ultimo_saldo, sinal = TRUE),
                    nota_intervalo(r$ultimo_dias)),
        estatistica("Saldo 7 dias", fmt_num(r$saldo_7d, sinal = TRUE),
                    if (!is.na(r$dias_7d) && r$dias_7d < 7)
                      paste0(r$dias_7d, ifelse(r$dias_7d == 1, " dia", " dias"), " de dados")),
        estatistica("Média diária", fmt_num(r$media_dia, sinal = TRUE),
                    if (!is.na(r$media_dia)) paste("desde", fmt_data(r$data_inicial))))
  )
}

card_comparativo <- function(dif, candidatos, resumo) {
  ult <- dif[nrow(dif), ]
  lider <- if (ult$diferenca >= 0) candidatos[2, ] else candidatos[1, ]
  atras <- if (ult$diferenca >= 0) candidatos[1, ] else candidatos[2, ]
  razao <- max(ult[[candidatos$id[1]]], ult[[candidatos$id[2]]]) /
    min(ult[[candidatos$id[1]]], ult[[candidatos$id[2]]])

  variacao <- if (nrow(dif) > 1) {
    v <- abs(ult$diferenca) - abs(dif$diferenca[1])
    paste0(ifelse(v > 0, "Aumentou ", ifelse(v < 0, "Caiu ", "Estável: ")),
           fmt_num(abs(v)), " desde ", fmt_data(dif$data[1]))
  } else {
    "Variação disponível a partir da 2ª coleta"
  }

  dias <- as.numeric(DATA_ELEICAO - max(dif$data))
  rotulo_dias <- if (dias > 0) dias else if (dias == 0) "Hoje" else "Encerrado"
  div(
    class = "comp-card",
    div(class = "cand-stat-rot", "Diferença atual"),
    div(class = "cand-hero", fmt_num(abs(ult$diferenca))),
    div(class = "cand-hero-rot",
        paste0(lider$nome_urna, " à frente · ",
               fmt_num(razao, 1), "× os seguidores de ", atras$nome_urna)),
    div(class = "comp-linha", variacao),
    div(class = "cand-stats",
        estatistica("Dias até o 2º turno", rotulo_dias,
                    fmt_data(DATA_ELEICAO, ano = TRUE)),
        estatistica("Última coleta", fmt_data(max(dif$data))),
        estatistica("Coletas", nrow(dif)))
  )
}

linha_tabela <- function(rotulo, valores, ajuda = NULL) {
  tags$tr(tags$th(scope = "row", rotulo,
                  if (!is.null(ajuda)) div(class = "tab-ajuda", ajuda)),
          lapply(valores, tags$td))
}

tabela_resumo <- function(resumo, candidatos) {
  com_data <- function(v, d) ifelse(is.na(v), "–",
                                    paste0(fmt_num(v, sinal = TRUE), " (", fmt_data(d), ")"))
  tags$table(
    class = "tab-resumo",
    tags$thead(tags$tr(
      tags$th(scope = "col", ""),
      lapply(seq_len(nrow(candidatos)), function(i)
        tags$th(scope = "col",
                span(class = "marcador", style = paste0("background:", candidatos$cor[i])),
                candidatos$nome_urna[i]))
    )),
    tags$tbody(
      linha_tabela("Seguidores atuais", fmt_num(resumo$atual)),
      linha_tabela("Primeira coleta",
                   paste0(fmt_num(resumo$inicial), " (", fmt_data(resumo$data_inicial), ")")),
      linha_tabela("Ganho acumulado", fmt_num(resumo$ganho_total, sinal = TRUE)),
      linha_tabela("Crescimento acumulado", fmt_pct(resumo$ganho_pct)),
      linha_tabela("Média diária", fmt_num(resumo$media_dia, sinal = TRUE),
                   "ganho acumulado ÷ dias decorridos"),
      linha_tabela("Crescimento médio diário", fmt_pct(resumo$media_pct_dia, 3),
                   "taxa composta"),
      linha_tabela("Mediana do saldo diário", fmt_num(resumo$mediana_dia, sinal = TRUE)),
      linha_tabela("Desvio-padrão do saldo diário", fmt_num(resumo$dp_dia)),
      linha_tabela("Maior saldo diário", com_data(resumo$maior, resumo$data_maior)),
      linha_tabela("Menor saldo diário", com_data(resumo$menor, resumo$data_menor)),
      linha_tabela(paste("Projeção para", fmt_data(DATA_ELEICAO)), fmt_num(resumo$projecao),
                   "atual + média diária × dias restantes"),
      linha_tabela("Dias com coleta", resumo$n_coletas)
    )
  )
}

# ---- Gráficos ---------------------------------------------------------------

layout_base <- function(p, eixo_y = list(), eixo_x = list(), margem_dir = 24, ...) {
  p |>
    layout(
      font = list(family = "system-ui, -apple-system, 'Segoe UI', sans-serif",
                  size = 12, color = TINTA_2),
      paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      separators = ",.",
      margin = list(l = 8, r = margem_dir, t = 8, b = 8),
      hovermode = "x unified",
      hoverlabel = list(bgcolor = SUPERFICIE, bordercolor = EIXO,
                        font = list(color = TINTA)),
      legend = list(orientation = "h", x = 0, y = 1.02, yanchor = "bottom",
                    font = list(color = TINTA_2)),
      xaxis = modifyList(list(showgrid = FALSE, linecolor = EIXO, ticks = "",
                              tickfont = list(color = TINTA_MUDA), title = "",
                              fixedrange = TRUE), eixo_x),
      yaxis = modifyList(list(gridcolor = GRADE, zeroline = FALSE, linecolor = EIXO,
                              tickfont = list(color = TINTA_MUDA), title = "",
                              tickformat = ",d", automargin = TRUE,
                              fixedrange = TRUE), eixo_y),
      ...
    ) |>
    config(displayModeBar = FALSE, locale = "pt-BR")
}

eixo_datas <- function(datas, eventos) {
  fim <- max(c(datas, eventos$data))
  list(type = "date", range = c(min(datas) - 0.6, fim + 0.6),
       tickformat = "%d/%m", hoverformat = "%d/%m/%Y", dtick = 86400000 * 2)
}

marcos <- function(eventos) {
  list(
    shapes = lapply(seq_len(nrow(eventos)), function(i) list(
      type = "line", x0 = eventos$data[i], x1 = eventos$data[i],
      yref = "paper", y0 = 0, y1 = 1, layer = "below",
      line = list(color = EIXO, width = 1))),
    annotations = lapply(seq_len(nrow(eventos)), function(i) list(
      x = eventos$data[i], y = 1, yref = "paper", text = eventos$evento[i],
      showarrow = FALSE, xanchor = "right", yanchor = "top", xshift = -4,
      font = list(size = 11, color = TINTA_MUDA)))
  )
}

# tipo = "absoluto" (seguidores) ou "pct" (crescimento acumulado desde a 1ª coleta)
grafico_evolucao <- function(diario, candidatos, eventos, tipo = "absoluto") {
  p <- plot_ly()
  rotulos <- list()
  for (i in seq_len(nrow(candidatos))) {
    cand <- candidatos[i, ]
    d <- diario[diario$candidato == cand$id, ]
    if (!nrow(d)) next
    y <- if (tipo == "pct") d$acumulado_pct else d$seguidores
    texto <- if (tipo == "pct") {
      paste0(fmt_pct(d$acumulado_pct), " (", fmt_num(d$acumulado, sinal = TRUE), ")")
    } else {
      paste0(fmt_num(d$seguidores), ifelse(is.na(d$saldo), "",
                                           paste0(" (", fmt_num(d$saldo, sinal = TRUE), ")")))
    }
    p <- p |> add_trace(
      type = "scatter", mode = "lines+markers", x = d$data, y = y,
      name = cand$nome_urna, customdata = texto,
      line = list(color = cand$cor, width = 2),
      marker = list(color = cand$cor, size = 8, line = list(color = SUPERFICIE, width = 2)),
      hovertemplate = paste0(cand$nome_urna, ": %{customdata}<extra></extra>")
    )
    rotulos[[length(rotulos) + 1]] <- list(
      x = d$data[nrow(d)], y = y[nrow(d)], text = cand$nome_urna, showarrow = FALSE,
      xanchor = "left", xshift = 8, font = list(color = TINTA, size = 12))
  }
  m <- marcos(eventos)
  eixo_y <- if (tipo == "pct") list(ticksuffix = "%", tickformat = ",.1f",
                                    zeroline = TRUE, zerolinecolor = EIXO) else list()
  layout_base(p, eixo_y = eixo_y, eixo_x = eixo_datas(diario$data, eventos),
              margem_dir = 96, shapes = m$shapes,
              annotations = c(m$annotations, rotulos))
}

# Série única: a diferença entre o 2º e o 1º candidato de data/candidatos.csv
grafico_diferenca <- function(dif, eventos) {
  if (nrow(dif) < 2) return(aguardando("Aguardando a 2ª coleta para mostrar a evolução."))
  texto <- paste0(fmt_num(dif$diferenca),
                  ifelse(is.na(lag(dif$diferenca)), "",
                         paste0(" (", fmt_num(dif$diferenca - lag(dif$diferenca), sinal = TRUE), ")")))
  m <- marcos(eventos)
  p <- plot_ly() |>
    add_trace(
      type = "scatter", mode = "lines+markers", x = dif$data, y = dif$diferenca,
      name = "Diferença", customdata = texto, showlegend = FALSE,
      line = list(color = TINTA_2, width = 2),
      marker = list(color = TINTA_2, size = 8, line = list(color = SUPERFICIE, width = 2)),
      hovertemplate = "Diferença: %{customdata}<extra></extra>"
    )
  layout_base(p, eixo_x = eixo_datas(dif$data, eventos),
              shapes = m$shapes, annotations = m$annotations)
}

# tipo = "absoluto" (seguidores/dia) ou "pct" (% ao dia)
grafico_saldo_diario <- function(diario, candidatos, eventos, tipo = "absoluto") {
  d_all <- diario[!is.na(diario$saldo), ]
  if (!nrow(d_all)) return(aguardando())
  p <- plot_ly()
  for (i in seq_len(nrow(candidatos))) {
    cand <- candidatos[i, ]
    d <- d_all[d_all$candidato == cand$id, ]
    if (!nrow(d)) next
    y <- if (tipo == "pct") d$saldo_pct_dia else d$saldo_dia
    texto <- if (tipo == "pct") fmt_pct(d$saldo_pct_dia, 3) else fmt_num(d$saldo_dia, sinal = TRUE)
    texto <- paste0(texto, ifelse(d$dias > 1, paste0(" (média de ", d$dias, " dias)"), ""))
    p <- p |> add_trace(
      type = "bar", x = d$data, y = y, name = cand$nome_urna, customdata = texto,
      marker = list(color = cand$cor, line = list(width = 0)),
      hovertemplate = paste0(cand$nome_urna, ": %{customdata}<extra></extra>")
    )
  }
  eixo_y <- list(zeroline = TRUE, zerolinecolor = EIXO)
  if (tipo == "pct") eixo_y <- c(eixo_y, list(ticksuffix = "%", tickformat = ",.2f"))
  eixo_x <- eixo_datas(d_all$data, eventos[0, ])
  eixo_x$range <- c(min(d_all$data) - 0.7, max(d_all$data) + 0.7)
  layout_base(p, eixo_y = eixo_y, eixo_x = eixo_x,
              barmode = "group", bargap = 0.35, bargroupgap = 0.08)
}

grafico_saldo_semanal <- function(semanal, candidatos) {
  if (!nrow(semanal)) return(aguardando())
  semanas <- sort(unique(semanal$semana))
  rotulo <- fmt_semana(semanas)
  p <- plot_ly()
  for (i in seq_len(nrow(candidatos))) {
    cand <- candidatos[i, ]
    d <- semanal[semanal$candidato == cand$id, ]
    if (!nrow(d)) next
    parcial <- ifelse(d$dias < 7, paste0(" (parcial: ", d$dias,
                                         ifelse(d$dias == 1, " dia)", " dias)")), "")
    p <- p |> add_trace(
      type = "bar", x = rotulo[match(d$semana, semanas)], y = d$saldo,
      name = cand$nome_urna,
      customdata = paste0(fmt_num(d$saldo, sinal = TRUE), parcial),
      marker = list(color = cand$cor, line = list(width = 0)),
      hovertemplate = paste0(cand$nome_urna, ": %{customdata}<extra></extra>")
    )
  }
  layout_base(p, eixo_y = list(zeroline = TRUE, zerolinecolor = EIXO),
              eixo_x = list(type = "category", categoryorder = "array",
                            categoryarray = rotulo),
              barmode = "group", bargap = 0.45, bargroupgap = 0.08)
}

# ---- Tabela de dados --------------------------------------------------------

tabela_dados <- function(diario, candidatos) {
  largo <- diario |>
    select(data, candidato, seguidores, saldo_dia) |>
    tidyr::pivot_wider(names_from = candidato,
                       values_from = c(seguidores, saldo_dia)) |>
    arrange(desc(data))
  colunas <- c("data", unlist(lapply(candidatos$id, function(id)
    c(paste0("seguidores_", id), paste0("saldo_dia_", id)))))
  largo <- largo[, intersect(colunas, names(largo))]
  nomes <- c("Data", unlist(lapply(candidatos$nome_urna, function(n)
    c(paste(n, "· seguidores"), paste(n, "· saldo/dia")))))
  largo$data <- format(largo$data, "%d/%m/%Y")

  DT::datatable(
    largo, colnames = nomes, rownames = FALSE, extensions = "Buttons",
    fillContainer = FALSE,
    options = list(
      dom = "Bt", paging = FALSE, ordering = FALSE,
      buttons = list(list(extend = "csv", text = "Baixar CSV"),
                     list(extend = "excel", text = "Baixar Excel")),
      columnDefs = list(list(className = "dt-right", targets = seq_along(nomes)[-1] - 1))
    )
  ) |>
    DT::formatRound(columns = 2:length(nomes), digits = 0, mark = ".", dec.mark = ",")
}
