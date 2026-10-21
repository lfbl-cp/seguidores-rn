# Seguidores · Governo do RN 2º turno

Painel diário de seguidores no **Instagram** dos candidatos ao governo do Rio Grande do Norte no 2º turno de 2026:

- **Cadu de Lula** (PT, 13)
- **Allyson** (União Brasil, 44)

O painel mostra a série de seguidores, o crescimento acumulado, os saldos diário e semanal, a diferença entre os candidatos e estatísticas descritivas. O painel é publicado no GitHub Pages e se atualiza sozinho sempre que uma planilha nova é enviada.

**Painel:** <https://lfbl-cp.github.io/seguidores-rn/>

---

## Registrar a coleta do dia

Faça a coleta **uma vez por dia, sempre no mesmo horário** (sugestão: 9h). Assim cada saldo diário cobre 24 horas.

A coleta fica na planilha `data/seguidores instagram.xlsx`.

1. Baixe a planilha atual do GitHub: abra o arquivo e clique em **Download raw file**. Não use uma cópia antiga do seu computador, para não perder coletas feitas por outra pessoa.
2. No Excel, acrescente uma linha no final com a data e os números de cada candidato:

   | data | cadu | alysson |
   |---|---|---|
   | 15/10/2026 | 150953 | 475258 |
   | 16/10/2026 | 151340 | 475990 |

   - Mantenha o cabeçalho exatamente como está: `data`, `cadu`, `alysson`.
   - Escreva os números inteiros e sem casas decimais.
   - Registre sempre o número exato, nunca o arredondado (como "151 mil"), e use o mesmo método de coleta todos os dias.
   - Se não conseguir coletar um candidato num dia, deixe a célula vazia. O painel calcula a média diária do intervalo.
3. Salve **sem mudar o nome do arquivo**.
4. No GitHub, entre na pasta [`data/`](data), clique em **Add file → Upload files**, arraste a planilha e clique em **Commit changes**. O arquivo com o mesmo nome é substituído.

Uns 3 a 5 minutos depois, o painel publicado já mostra a nova coleta. Para acompanhar, abra a aba **Actions** do repositório.

### Se a atualização falhar

Quando há erro de digitação, como data repetida, texto no lugar do número ou data inválida, a publicação é interrompida e **o painel continua mostrando a versão anterior**. Abra a aba **Actions**, clique na execução com o ❌ e procure a mensagem de erro. Ela diz a planilha, a coluna e a linha com problema. Corrija a planilha e envie de novo.

## Marcar eventos nos gráficos

Debates, pesquisas e outros fatos que expliquem picos podem aparecer como linhas verticais nos gráficos de todas as redes. Para isso, acrescente uma linha em [`data/eventos.csv`](data/eventos.csv). Esse arquivo pode ser editado direto no GitHub, pelo lápis:

```
data,evento
2026-10-20,Debate TV
2026-10-25,2º turno
```

## Incluir outra rede social

1. Crie a planilha `data/seguidores <rede>.xlsx` no mesmo padrão da planilha do Instagram.
2. Acrescente uma linha em `data/redes.csv` (id, nome exibido, caminho da planilha).
3. Em `index.qmd`, copie o bloco de uma rede (o título da rede, o bloco que define `rd` e o `include`) e troque o id. Faça o mesmo na página **Dados**.

## Estrutura

```
data/seguidores *.xlsx  coleta diária, uma planilha por rede (editadas pela equipe)
data/redes.csv          redes monitoradas e suas planilhas
data/candidatos.csv     nome de urna, partido, número, cor e foto de cada candidato
data/eventos.csv        marcos exibidos nos gráficos
img/                    fotos oficiais de divulgação do TSE
R/funcoes.R             leitura, validação, métricas e gráficos
index.qmd               o painel (Quarto Dashboard): uma página por rede
_painel_rede.qmd        conteúdo de cada página de rede
custom.scss             estilo visual
.github/workflows/      renderização e publicação automáticas
```

As cores dos candidatos ficam em `data/candidatos.csv`: vermelho `#e34948` para Cadu de Lula e azul `#2a78d6` para Allyson. A coluna `id` desse arquivo precisa ser igual ao cabeçalho das planilhas. A data da eleição fica no início de `R/funcoes.R`.

## Configuração inicial (uma vez)

1. O repositório é <https://github.com/lfbl-cp/seguidores-rn> (precisa ser **público** para o Pages gratuito).
2. Em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions**.
3. Abra a aba **Actions**, rode o workflow **Publicar painel** (**Run workflow**) e espere terminar.

## Rodar no computador (opcional)

São necessários o R e o Quarto. O Quarto já vem instalado junto com o RStudio. Instale os pacotes uma vez:

```r
install.packages(c("knitr", "rmarkdown", "dplyr", "tidyr", "plotly", "DT", "htmltools", "readxl"))
```

Depois abra `index.qmd` no RStudio e clique em **Render**. Outra opção é rodar `quarto render` no terminal. O resultado fica em `_site/index.html`.
