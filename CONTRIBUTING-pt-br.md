# Contribuindo

> Esta é a tradução em português do [`CONTRIBUTING.md`](./CONTRIBUTING.md). Em caso de
> divergência entre os dois, o arquivo em inglês é a referência.

## Estrutura de pastas

```
skills/
  general/<nome>/             # válida para FTC e FRC
  frc/frc-<nome>/             # exclusiva de FRC, nome prefixado com frc-
  ftc/ftc-<nome>/             # exclusiva de FTC, nome prefixado com ftc-
  _template/                  # origem do scaffold — não edite skills no lugar, copie este
```

Cada pasta de skill é uma skill simples, neutra em relação à ferramenta (harness): `SKILL.md`
(+ opcionalmente `scripts/`, `references/`). Esse é o conteúdo canônico, editado à mão.
`.claude-plugin/plugin.json` e os três arquivos
`skills/{general,frc,ftc}/.claude-plugin/marketplace.json` são **gerados** pela CI
(`scripts/ci/generate-marketplaces.sh`) — nunca edite à mão, eles são sobrescritos.

## Começando uma skill nova

Tem uma ideia mas ainda sem spec? Abra uma issue
[**skill idea**](../../issues/new?template=skill-idea.yml). Já tem escopo/nome/spec definidos?
Abra uma issue [**new skill**](../../issues/new?template=new-skill.yml) diretamente.

Se você estiver usando Claude Code dentro deste repositório, a skill `create-skill`
(`.claude/skills/create-skill/`) conduz os dois fluxos do início ao fim — triando uma issue
`skill idea` até virar uma issue `new skill`, e transformando uma issue `new skill` em um branch +
PR já montados. Aponte-a para o número da issue e ela cuida do nome do branch, do scaffold e da
abertura do PR.

Para montar manualmente:

```
./scripts/new-skill.sh <general|frc|ftc> <nome-da-skill>
```

Monta `skills/<escopo>/<nome-da-skill>/` a partir de `skills/_template/`. Nomes de FRC/FTC devem
ser prefixados (`frc-...` / `ftc-...`); nomes gerais ficam sem prefixo.

## Implementando uma issue já existente

Navegue pela label [`new skill`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22new+skill%22) em
busca de skills que já têm escopo/nome/spec definidos e só precisam ser implementadas — o lote
inicial veio direto do `SPEC.md`. Escolha uma que ninguém mais esteja fazendo.

Se você estiver usando Claude Code neste repositório, aponte a skill `create-skill`
(`.claude/skills/create-skill/`) para o número da issue e ela conduz tudo: branch (`feat/<nome>`),
scaffold (`scripts/new-skill.sh`), escrita do `SKILL.md` a partir dos campos `description`/`spec`
da issue, validação local, commit, push e abertura do PR com `Closes #<n>`. Ela para por aí —
nunca faz o merge do próprio PR.

Fazendo manualmente, siga os mesmos passos você mesmo: crie o branch a partir de `feat/<nome>`,
rode `./scripts/new-skill.sh <escopo> <nome>`, escreva o `SKILL.md`, rode
`bash scripts/ci/validate-skills.sh` antes de commitar, e referencie `Closes #<n>` no corpo do PR
para que a issue feche automaticamente no merge.

## Uma skill, um PR

Todo PR mexe em exatamente um `skills/<escopo>/<nome>/`. O nome do branch decide o tipo de
incremento de versão no merge:

| Prefixo do branch | Incremento |
|---|---|
| `fix/...`     | patch |
| `feat/...`    | minor |
| `release/...` | major |

Qualquer outro prefixo (`chore/...`, `docs/...`) faz merge normalmente, sem gerar release.

## Merge

Duas coisas liberam o merge para `main`:

1. **Duas revisões de colaboradores** (branch protection) — o julgamento humano: a skill faz o
   que promete, a escrita está boa, o escopo está certo.
2. **`ci.yml`** — uma checagem estrutural determinística (`scripts/ci/validate-skills.sh`), sem
   julgamento de conteúdo: o `SKILL.md` existe no caminho certo, seu frontmatter é válido e tem
   `name` + `description`, o nome no frontmatter bate com o nome da pasta, o prefixo FRC/FTC está
   correto, e o nome é único entre os três escopos.

No merge, o `release.yml` lê o prefixo do branch, encontra a única pasta de skill que o PR alterou,
cria a tag `<nome>@x.y.z`, regenera os arquivos `.claude-plugin` e publica uma GitHub Release.

## Instalando uma skill em um repositório de robô

```
curl -fsSL https://raw.githubusercontent.com/heitorsDev/first-robotics-skills/main/install.sh | sh -s -- <nome-da-skill>
```

Copia `skills/<escopo>/<nome-da-skill>/` para `.claude/skills/<nome-da-skill>/` no repositório
atual — o diretório que tanto o Claude Code quanto o opencode leem. Quem usa Claude Code também
pode adicionar diretamente um dos três marketplaces:

```
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/frc
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/ftc
claude plugin marketplace add heitorsDev/first-robotics-skills --path skills/general
```

Os marketplaces `frc` e `ftc` já incluem as skills `general`, então um único `add` cobre a
necessidade de um time.
