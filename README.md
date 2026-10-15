# Seguidores · Governo do RN 2º turno

Painel diário de seguidores no Instagram dos candidatos ao governo do Rio Grande do Norte no 2º turno de 2026:

- **Cadu de Lula** (PT, 13)
- **Allyson** (União Brasil, 44)

O painel mostra a série de seguidores, o crescimento acumulado, os saldos diário e semanal, a diferença entre os candidatos e estatísticas descritivas. Ele é publicado no GitHub Pages e se atualiza sozinho sempre que uma nova coleta é registrada.

**Painel:** <https://lfbl-cp.github.io/seguidores-rn/>

---

## Registrar a coleta do dia

Faça a coleta **uma vez por dia, sempre no mesmo horário** (sugestão: 9h). Assim cada saldo diário cobre 24 horas.

1. No GitHub, abra o arquivo [`data/seguidores.csv`](data/seguidores.csv) e clique no lápis (**Edit this file**).
2. Acrescente uma linha no final, com a data e os números de cada candidato:

   ```
   data,cadu,allyson
   2026-10-15,150953,475258
   2026-10-16,151340,475990
   ```

   - Escreva a data como `AAAA-MM-DD`. `16/10/2026` também é aceito.
   - Escreva os números sem casas decimais. Os formatos `151340`, `151.340` e `151 340` são aceitos.
   - Registre sempre o número exato, nunca o arredondado (como "151 mil"), e use o mesmo método de coleta todos os dias.
   - Se não conseguir coletar um candidato num dia, deixe o campo vazio. O painel calcula a média diária do intervalo.
3. Clique em **Commit changes**.

Uns 3 a 5 minutos depois, o painel publicado já mostra a nova coleta. Para acompanhar, abra a aba **Actions** do repositório.

### Se a atualização falhar

Quando há erro de digitação, como data repetida, letra no número ou data inválida, a publicação é interrompida e **o painel continua mostrando a versão anterior**. Abra a aba **Actions**, clique na execução com o ❌ e procure a mensagem de erro. Ela diz o problema e a linha do CSV. Corrija o arquivo e faça um novo commit.

## Marcar eventos nos gráficos

Debates, pesquisas e outros fatos que expliquem picos podem aparecer como linhas verticais nos gráficos. Para isso, acrescente uma linha em [`data/eventos.csv`](data/eventos.csv):

```
data,evento
2026-10-20,Debate TV
2026-10-25,2º turno
```

## Estrutura

```
data/seguidores.csv   coleta diária (fonte dos dados; editada pela equipe)
data/candidatos.csv   nome de urna, partido, número, cor e foto de cada candidato
data/eventos.csv      marcos exibidos nos gráficos
img/                  fotos oficiais de divulgação do TSE
R/funcoes.R           leitura, validação, métricas e gráficos
index.qmd             o painel (Quarto Dashboard)
custom.scss           estilo visual
.github/workflows/    renderização e publicação automáticas
```

As cores dos candidatos ficam em `data/candidatos.csv`: vermelho `#e34948` para Cadu de Lula e azul `#2a78d6` para Allyson. A rede monitorada e a data da eleição ficam no início de `R/funcoes.R`.

## Configuração inicial (uma vez)

1. O repositório é <https://github.com/lfbl-cp/seguidores-rn> (precisa ser **público** para o Pages gratuito).
2. Em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions**.
3. Abra a aba **Actions**, rode o workflow **Publicar painel** (**Run workflow**) e espere terminar. O endereço do painel aparece no resumo da execução.

## Rodar no computador (opcional)

São necessários o R e o Quarto. O Quarto já vem instalado junto com o RStudio. Instale os pacotes uma vez:

```r
install.packages(c("knitr", "rmarkdown", "dplyr", "tidyr", "plotly", "DT", "htmltools"))
```

Depois abra `index.qmd` no RStudio e clique em **Render**. Outra opção é rodar `quarto render` no terminal. O resultado fica em `_site/index.html`.
