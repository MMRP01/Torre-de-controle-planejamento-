# Colocando a ferramenta online, com vários usuários em tempo real

A tela da ferramenta fica no **GitHub Pages**. Os dados, o login e o tempo real ficam no **Supabase** (um serviço
de banco de dados com plano gratuito). Cada pessoa entra com o próprio e-mail e senha, e o que uma pessoa altera
aparece para as outras em poucos segundos, sem recarregar a página.

Tempo estimado: 20 a 30 minutos. Você precisa de uma conta no GitHub e uma no Supabase.

---

## 1. Criar o projeto no Supabase
1. Acesse **supabase.com** → *Start your project* → entre (pode usar a conta do GitHub).
2. **New project**. Dê um nome (ex.: `producao-menzoil`), escolha uma **senha do banco** (guarde-a) e a região
   **South America (São Paulo)** (os dados ficam no Brasil e a resposta é mais rápida).
3. Aguarde 1 a 2 minutos até o projeto ficar pronto.

## 2. Criar as tabelas e as regras de segurança
1. No painel do projeto: **SQL Editor** → **New query**.
2. Abra o arquivo `supabase/schema.sql` deste pacote, copie **tudo**, cole no editor e clique **Run**.
3. Deve aparecer *Success. No rows returned*. (Pode rodar de novo quando atualizar a ferramenta: é seguro.)

## 3. Ajustar o login
1. **Authentication → Providers → Email**: deixe **Email** habilitado.
2. Para uso interno, **desmarque "Confirm email"**. Assim, quem cria a conta entra direto (depois o administrador libera).
   Se deixar marcado, cada pessoa terá de clicar em um link recebido por e-mail, e o plano gratuito envia poucas
   mensagens por hora.
3. **Authentication → URL Configuration → Site URL**: coloque o endereço onde a ferramenta vai ficar
   (ex.: `https://SEU-USUARIO.github.io/planejamento-producao/`). É para onde levam os links de "Esqueci a senha".

## 4. Ligar e conferir o tempo real (é o que faz as alterações aparecerem para os outros sem recarregar)
O `schema.sql` já tenta ligar o tempo real nas tabelas certas. **Confira**, rodando no **SQL Editor**:
```sql
select tablename from public.pg_publication_tables where pubname = 'supabase_realtime';
```
O resultado deve listar **`registros`** e **`perfis`**. Se não listar (ou se vier vazio), rode estas duas linhas:
```sql
alter publication supabase_realtime add table public.registros;
alter publication supabase_realtime add table public.perfis;
```
(Se aparecer "already member of publication", já estava ligado.) No painel, o mesmo ajuste aparece em
*Database → Publications → supabase_realtime* ou, na tabela, no botão de **Realtime** do *Table Editor* — os nomes podem
mudar conforme a versão do painel.

> **Se o tempo real não estiver funcionando, a ferramenta continua compartilhada**: ela percebe sozinha e passa a buscar
> as mudanças dos outros a cada poucos segundos (a barra lateral mostra "● Online · atualiza a cada 5 s"). Só não é
> instantâneo. Depois de ligar o tempo real, volta ao normal sozinha.

### Teste de simultaneidade (2 minutos)
1. Abra a ferramenta em **dois navegadores diferentes** (ou um normal e uma janela anônima), cada um com **uma conta diferente** (ambas liberadas, com "Edição" na Lista Mestre).
2. Na barra lateral, os dois devem mostrar **"● Online · 2 conectados"**. (O "2 conectados" também depende do tempo real: se mostrar só 1, ele não está funcionando.)
3. No navegador 1, abra **Lista Mestre**, escolha uma linha e digite algo no campo **Nº OP**. Saia do campo.
4. No navegador 2, o valor deve aparecer **sozinho**, em instantes, e um aviso "🔄 Fulano atualizou 1 registro".
5. Se não aparecer, clique em **"● Online"** na barra lateral (atualiza na hora) e rode **Usuários e Permissões → 🩺 Testar conexão**.

## 5. Copiar a URL e a chave
**Project Settings → API**:
- **Project URL** (ex.: `https://abcdefghijkl.supabase.co`)
- **Project API keys → `anon` `public`** (uma chave longa que começa com `eyJ…`)

Abra o arquivo **`config.js`** e preencha:
```js
window.MENZOIL_CONFIG = {
  supabaseUrl: 'https://abcdefghijkl.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi...'
};
```
> A chave `anon` é pública por desenho — pode ir para o GitHub. **Nunca** use a chave `service_role` aqui (a ferramenta recusa e avisa).
> A ferramenta corrige sozinha erros comuns da URL (falta de `https://`, espaços, barra no final, `/rest/v1`), mas confira sempre se ela é a **Project URL** do painel.

## 6. Publicar no GitHub Pages
1. Crie um repositório no GitHub e suba **todos** os arquivos do pacote: `index.html`, `config.js`, **`supabase.js`**,
   `README.md`, `.nojekyll` (e, se quiser guardar, as pastas `supabase/` e `docs/`).
   > O `supabase.js` é a biblioteca de conexão (108 KB). **Sem ele no repositório a ferramenta não consegue entrar online.**
2. **Settings → Pages → Deploy from a branch → `main` / (root)**. Em cerca de 1 minuto o site abre.
3. Domínio próprio (opcional): *Settings → Pages → Custom domain* + um registro CNAME no seu provedor de DNS.
   Depois, atualize o **Site URL** do passo 3.3.

## 7. Primeiro acesso — faça logo, antes de divulgar o endereço
1. Abra o site → **Criar conta** (seu nome, e-mail e senha).
2. **A primeira conta criada vira administradora automaticamente.** Por isso crie a sua *antes* de passar o endereço
   para outras pessoas.
3. Entre em **Usuários e Permissões → 🩺 Testar conexão**. Todos os passos devem ficar com ✓. Se algum falhar, a
   própria tela diz o que fazer (e a tabela "Problemas comuns", abaixo, também).

## 8. Colocar os dados no servidor (uma vez)
Escolha uma das opções:
- **A) Enviar o arquivo completo (recomendado se você usa a versão com os dados embutidos).** Copie o seu `config.js`
  preenchido para a mesma pasta do `index.html` **completo** (o privado), abra-o no navegador e entre como
  administrador. Como o servidor está vazio, a ferramenta pergunta *"Enviar esses dados ao servidor?"* → Confirmar.
  Itens, receitas, pedidos e recursos sobem em alguns segundos.
- **B) Importar planilhas** pelo site (Importação de Dados) e cadastrar os recursos (Cadastros → Recursos & Capacidade).
- **C) Restaurar um backup (.json)** em Importação de Dados.

Só depois do passo 7 (administrador criado) as outras pessoas podem usar.

## 9. Adicionar as pessoas
1. A pessoa abre o endereço e clica em **Criar conta**.
2. A conta aparece na hora em *Usuários e Permissões*, como **⏳ Aguardando liberação**.
3. Você clica **Liberar** e define o que ela vê e edita (por tela, por campo e, se quiser, **trava de filtros**).
4. Alterações de permissão chegam à pessoa **ao vivo**. **Desativar** derruba a sessão dela na hora.

---

## Como o trabalho simultâneo funciona
- Cada alteração é enviada ao servidor em segundos e aparece nas outras telas abertas. Quem está digitando não é
  interrompido: a tela dele só atualiza quando ele sai do campo.
- Duas pessoas mexendo em **campos diferentes** do mesmo registro: as duas alterações valem. No **mesmo campo**: vale a
  última gravação.
- Sem internet: o indicador mostra "⚠ Sem conexão — N alteração(ões) aguardando". Ao voltar, a ferramenta envia o que
  ficou pendente e baixa o que perdeu.
- O servidor **recusa** gravação de quem só tem leitura e de quem tenta mudar a programação de uma linha que já tem
  produção (só administrador). Nesses casos a tela volta ao valor correto e avisa.
- **Gerar plano** é uma ação que mexe em muitas linhas: evite que duas pessoas gerem o plano ao mesmo tempo.

## Funciona para mim, mas outras pessoas não conseguem entrar
Use a página de **diagnóstico**, que já vem no pacote (`diagnostico.html`):
1. Peça para a pessoa abrir, **no navegador dela**, o endereço do seu site com `diagnostico.html` no final, por exemplo
   `https://SEU-USUARIO.github.io/NOME-DO-REPOSITORIO/diagnostico.html`.
2. Clicar em **Executar diagnóstico** (leva até 20 segundos) e depois em **Copiar relatório**.
3. Enviar o relatório para você. Ele diz, passo a passo, o que falha: a versão publicada da ferramenta, se o `config.js` e o
   `supabase.js` estão no GitHub, se a URL e a chave estão certas, se o servidor responde, se o login e as tabelas existem
   e se o tempo real abre. (A chave aparece abreviada no relatório.)

Causas frequentes, em ordem: **cópia antiga em cache** (peça Ctrl+F5 ou uma janela anônima; o relatório mostra a versão),
**`config.js` publicado diferente do que você usa** (o relatório mostra se está em branco), arquivo **`supabase.js` ou
`config.js` que não subiu** ao GitHub, e só então bloqueio de rede (teste também pelo celular em 4G/5G).
A tela de erro da ferramenta também mostra "Detalhes técnicos" (versão, endereço da página e do servidor) para copiar.

## Problemas comuns
| O que aparece | Causa provável | O que fazer |
|---|---|---|
| "Sem conexão com o servidor… não conseguiu falar com o servidor xxxx.supabase.co" | A **URL do `config.js` está errada** (a causa mais comum), o projeto está **pausado**, ou um bloqueador/antivírus/rede da empresa bloqueia `supabase.co` | Compare a URL com **Project Settings → API → Project URL**. Abra essa URL no navegador: se não carregar, é rede ou projeto pausado (*Restore project*). Teste pelo celular |
| "O servidor respondeu, mas recusou a chave" | Chave `anon` copiada incompleta, ou de outro projeto | Copie de novo a chave **anon public** (a longa, começa com `eyJ`) do mesmo projeto da URL |
| "A chave colocada no config.js é a service_role" | Foi colada a chave **secreta** | Troque pela **anon public** e, por segurança, gere uma nova `service_role` no painel (a antiga foi exposta) |
| "Não foi possível carregar a biblioteca de conexão" | O `supabase.js` não foi enviado ao GitHub (ou rede bloqueia CDNs) | Suba o `supabase.js` na mesma pasta do `index.html` |
| A tela abre, mas sem login online (parece o modo antigo) | `config.js` em branco, ou o arquivo errado foi enviado | Abra `https://SEU-SITE/config.js` no navegador: deve mostrar a sua URL e chave |
| "Não foi possível ler os dados" no teste | O `schema.sql` não foi executado por inteiro, ou URL/chave de outro projeto | Rode o `schema.sql` de novo; confira o `config.js` |
| "Tempo real" falha no teste | Tabelas fora da publicação, ou rede da empresa bloqueia WebSocket | Passo 4; teste em outra rede (celular) |
| As alterações de uma pessoa só aparecem para a outra depois de um tempo, ou só ao recarregar | Tempo real desligado no Supabase (a ferramenta está usando a atualização de reserva), ou a outra pessoa tem só **leitura** | Passo 4 (SQL do Realtime) e 🩺 Testar conexão. Confira também se a outra conta tem **Edição** na tela |
| "2 conectados" não aparece (mostra só você) | Tempo real/presença desligado | Passo 4 |
| Conta criada, mas "Aguardando liberação" | É o esperado | O administrador libera em Usuários e Permissões |
| "Confirme o e-mail primeiro" | "Confirm email" está ligado | Passo 3.2 (ou clique no link do e-mail) |
| Link de "Esqueci a senha" abre página errada | Site URL incorreto | Passo 3.3 |
| Não deixa rebaixar um administrador | Regra de segurança: sempre deve existir um administrador ativo | Promova outro antes |
| Projeto "pausado" | Plano gratuito pausa após cerca de 1 semana sem uso | No painel do Supabase, clique em *Restore project* |

## Biblioteca do Supabase
O arquivo `supabase.js` que acompanha o pacote é a biblioteca oficial do Supabase (versão 2.45.4). A ferramenta a carrega
dele; só se o arquivo não estiver na pasta é que tenta baixá-la de CDNs públicas (jsDelivr e unpkg). Se aparecer
"Não foi possível carregar a biblioteca de conexão", confira se o `supabase.js` foi enviado ao GitHub, na mesma pasta do `index.html`.

## Backup, custo e segurança
- **Backup:** no plano gratuito não há backup automático com retorno no tempo. Use **Importação de Dados →
  Exportar backup** com frequência e guarde o arquivo **fora do GitHub** (tem dados reais).
- **Custo:** o plano gratuito atende bem uma equipe pequena. Confira os limites atuais (armazenamento, conexões
  simultâneas, e-mails por hora) no site do Supabase. Para mais pessoas ou mais garantias, existem planos pagos.
- **Segurança:** só quem está logado **e ativo** lê os dados; ninguém grava direto nas tabelas (só pela função do
  servidor, que confere permissão, versão e a trava de linha produzida). Campos por tela e travas de filtro organizam
  o uso; o servidor garante, no mínimo, que quem só consulta nunca grava.
- **LGPD:** os dados ficam no Supabase, na região que você escolheu. Trate o acesso ao painel do Supabase e à senha
  do banco como confidenciais.
