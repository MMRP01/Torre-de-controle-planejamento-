# Torre de Controle de Produção

Planejamento e acompanhamento de produção: Plano Mestre, Lista Mestre, Planejado x Efetuado, Prioridades, Paradas,
Refugo/Perdas, Capacidade, Pedidos & Lead Time e Dashboards.

**Funciona online, com vários usuários ao mesmo tempo:** cada pessoa entra com o próprio e-mail e senha, e o que uma
altera aparece para as outras em segundos, sem recarregar. A tela fica no GitHub Pages; os dados, o login e o tempo
real ficam no Supabase.

Esta versão **não traz nenhum dado**: eles vivem no servidor, protegidos por login e por regras de acesso.

## Para colocar no ar
Siga o guia **[docs/CONFIGURAR_SUPABASE.md](docs/CONFIGURAR_SUPABASE.md)** (20 a 30 minutos):
1. criar o projeto no Supabase e rodar `supabase/schema.sql`;
2. preencher `config.js` com a URL e a chave pública do projeto;
3. publicar estes arquivos no GitHub Pages;
4. criar a primeira conta (vira administradora) e usar **Usuários e Permissões → 🩺 Testar conexão**.

## Arquivos
| Arquivo | Para quê |
|---|---|
| `index.html` | a ferramenta inteira (sem dados) |
| `config.js` | URL e chave pública do Supabase (em branco = modo local, dados só neste navegador) |
| `supabase/schema.sql` | tabelas, regras de acesso e gravação com controle de conflito (rodar no SQL Editor) |
| `docs/CONFIGURAR_SUPABASE.md` | passo a passo e solução de problemas |

## Segurança em uma frase
Só quem está logado **e liberado pelo administrador** lê os dados; ninguém grava direto no banco (só pela função do
servidor, que confere permissão, versão e a trava de linha com produção). Contas novas ficam **aguardando liberação**.
Mantenha o arquivo de backup (.json) **fora deste repositório**: ele contém dados reais.
