%skeleton "lalr1.cc"
%require "3.2"

%parse-param {yy::scanner* scanner} {ParserOutput* cb}

%locations

%define api.value.type variant

%define parse.trace
%define parse.error verbose

%code requires {
  #include <stdexcept>
  #include <string>
  #include <vector>

  #include "ast.hpp"
  #include "location.hh"

  namespace yy {
    class scanner;
  };

  struct ParserOutput {
    int indent = 0;
    virtual void addStatement(ast::Statement*) = 0;
  };
} 

%code {
    #include <iostream>     // cerr, endl
    #include <utility>      // move
    #include <string>

    #include "parser/scanner.hpp"

    using std::move;

    #undef yylex
    #define yylex scanner->lex

    // utility function to append a list element to a std::vector
    template <class T, class V>
    T&& enlist(T& t, V& v)
    {
        t.push_back(move(v));
        return move(t);
    }
}

%start program
%token <std::string> IDENTIFIER
%token ASSIG
%token BECOMES
%token <double> NUMBER
%token PLUS
%token MINUS
%token TIMES
%token DIVIDED
%token LESS
%token GREATER
%token LESS_EQL
%token GREATER_EQL
%token <std::string> STRING
%token RPARENT
%token LPARENT
%token RBRACE
%token LBRACE
%token RBRACKET
%token LBRACKET
%token COLON
%token VARDEC
%token COMMA
%token PRINT
%token LOAD
%token TYPEOF
%token EXIT
%token EOL
%token PERIOD
%token CONSTDEC
%token EQUAL
%token UNKNOWN
%token FILE_END
%token IF
%token TRUE
%token FALSE
%token ARROW
%token RETURN
%token WHILE
%token STRING_TYPE
%token NUMBER_TYPE
%token BOOLEAN_TYPE
%token OBJECT_TYPE
%token ARRAY_TYPE
%token FUNCTION_TYPE

%type <ast::Identifier*> identifier
%type <ast::VarDeclaration*> vardec
%type <ast::Assignment*> assignment
%type <ast::Statement*> statement
%type <ast::Statement*> command
%type <ast::PrintStatement*> print
%type <ast::Expression*> literal
%type <ast::Expression*> expression
%type <std::vector<ast::Expression*>> list
%type <ast::Property*> property
%type <std::vector<ast::Property*>> properties
%type <ast::ObjectLiteral*> object
%type <ast::Branch*> branch
%type <ast::BooleanLiteral*> boolean
%type <std::vector<ast::Statement*>> scope
%type <std::vector<ast::Statement*>> statements
%type <ast::ArrayLiteral*> array
%type <ast::Pattern*> pattern
%type <ast::ExitStatement*> exit
%type <std::vector<ast::Identifier*>> param
%type <ast::FunctionLiteral*> function
%type <ast::CallStatement*> func_call
%type <ast::ReturnStatement*> return
%type <ast::WhileStatement*> while
%type <ast::TypeOf*> typeof
%type <ast::LoadStatement*> load
%type <ast::TypeCast*> type_cast

%%
program    : statement          { cb->addStatement($1); }
           | program statement  { cb->addStatement($2); }
           ;

identifier : IDENTIFIER { $$ = new ast::Identifier($1); }
           ;

pattern    : pattern PERIOD identifier               { $$ = new ast::Pattern($1, $3); }
           | identifier PERIOD identifier            { $$ = new ast::Pattern($1, $3); }
           | pattern LBRACKET expression RBRACKET { $$ = new ast::Pattern($1, $3); }
           | identifier LBRACKET expression RBRACKET { $$ = new ast::Pattern($1, $3); }
           ;

expression : identifier { $$ = $1; }
           | literal { $$ = $1; }
           | pattern                       { $$ = $1; }
           | func_call { $$ = $1; }
           | typeof { $$ = $1; }
           | type_cast { $$ = $1; }
           | expression expression PLUS        { $$ = new ast::Operation(ast::Operator::Addition, $1, $2); }
           | expression expression MINUS       { $$ = new ast::Operation(ast::Operator::Substraction, $1, $2); }
           | expression expression TIMES       { $$ = new ast::Operation(ast::Operator::Multiplication, $1, $2); }
           | expression expression DIVIDED     { $$ = new ast::Operation(ast::Operator::Division, $1, $2); }
           | expression EQUAL expression       { $$ = new ast::Operation(ast::Operator::Equal, $1, $3); }
           | expression LESS expression        { $$ = new ast::Operation(ast::Operator::Less, $1, $3); }
           | expression LESS_EQL expression    { $$ = new ast::Operation(ast::Operator::Greater, $1, $3); }
           | expression GREATER expression     { $$ = new ast::Operation(ast::Operator::GreaterEqual, $1, $3); }
           | expression GREATER_EQL expression { $$ = new ast::Operation(ast::Operator::LessEqual, $1, $3); }
           ;

type_cast  : expression COLON STRING_TYPE { $$ = new ast::TypeCast($1, ast::DataType::String); }
           | expression COLON NUMBER_TYPE { $$ = new ast::TypeCast($1, ast::DataType::Number); }
           | expression COLON BOOLEAN_TYPE { $$ = new ast::TypeCast($1, ast::DataType::Boolean); }
           | expression COLON OBJECT_TYPE { $$ = new ast::TypeCast($1, ast::DataType::Object); }
           | expression COLON ARRAY_TYPE { $$ = new ast::TypeCast($1, ast::DataType::Array); }
           | expression COLON FUNCTION_TYPE { $$ = new ast::TypeCast($1, ast::DataType::Function); }
           ;


return     : RETURN expression  { $$ = new ast::ReturnStatement($2); }
           ;

literal    : NUMBER { $$ = new ast::NumberLiteral($1); }
           | STRING { $$ = new ast::StringLiteral($1); }
           | boolean { $$ = $1; }
           | array   { $$ = $1; }
           | object { $$ = $1; }
           | function { $$ = $1; }
           ;

boolean    : TRUE  { $$ = new ast::BooleanLiteral(true); }
           | FALSE { $$ = new ast::BooleanLiteral(false); }
           ;

property   : identifier COLON expression { $$ = new ast::Property($1, $3); }
           ;

properties : property                   { $$ = std::vector<ast::Property*>(); enlist($$, $1); }
           | property COMMA properties  { $$ = enlist($3, $1); }
           | property COMMA EOL properties  { $$ = enlist($4, $1); }
           ;

array      : LBRACKET list RBRACKET { $$ = new ast::ArrayLiteral($2); }
           | LBRACKET EOL list EOL RBRACKET { $$ = new ast::ArrayLiteral($3); }
           ;

object     : LBRACE properties RBRACE { $$ = new ast::ObjectLiteral($2); }
           | LBRACE EOL properties EOL RBRACE { $$ = new ast::ObjectLiteral($3); }
           ;

list       : expression             { $$ = std::vector<ast::Expression*>(); enlist($$, $1); }
           | list COMMA expression  { $$ = enlist($1, $3); }
           | list COMMA EOL expression  { $$ = enlist($1, $4); }
           ;

param      : identifier             { $$ = std::vector<ast::Identifier*>(); enlist($$, $1); }
           | param COMMA identifier { $$ = enlist($1, $3); }

function   : LPARENT param RPARENT ARROW scope { $$ = new ast::FunctionLiteral($2, $5); }
           | LPARENT param RPARENT ARROW       { cb->indent++; }
           ;

func_call  : identifier LPARENT list RPARENT { $$ = new ast::CallStatement($1, $3); }
           ;

assig_op   : ASSIG
           | BECOMES
           ;

branch     : IF LPARENT expression RPARENT statement { $$ = new ast::Branch($3, $5); }
           | IF LPARENT expression RPARENT EOL statement { $$ = new ast::Branch($3, $6); }
           | IF LPARENT expression RPARENT scope     { $$ = new ast::Branch($3, $5); }
           | IF LPARENT expression RPARENT EOL scope     { $$ = new ast::Branch($3, $6); }
           | IF LPARENT expression RPARENT           { cb->indent++; }
           ;

scope      : LBRACE statements RBRACE                { $$ = $2; }
           | LBRACE EOL statements RBRACE        { $$ = $3; }
           | LBRACE statements                       { cb->indent++; }
           | LBRACE                                  { cb->indent++; }
           ;

assignment : identifier ASSIG expression             { $$ = new ast::Assignment($1, $3); }
           | identifier BECOMES expression           { $$ = new ast::Assignment($1, $3, true); }
           ;

vardec     : VARDEC identifier                       { $$ = new ast::VarDeclaration($2); }
           | VARDEC identifier ASSIG expression      { $$ = new ast::VarDeclaration($2, $4); }
           | VARDEC identifier BECOMES expression    { $$ = new ast::VarDeclaration($2, $4, true); }
           ;

constdec   : CONSTDEC identifier assig_op expression
           ;

statement  : vardec EOL              { $$ = $1; }
           | assignment EOL          { $$ = $1; }
           | branch EOL              { $$ = $1; }
           | constdec EOL
           | command EOL             { $$ = $1; }
           | expression EOL          { $$ = $1; }
           | return EOL              { $$ = $1; }
           | while EOL               { $$ = $1; }
           ;

while      : WHILE LPARENT expression RPARENT scope { $$ = new ast::WhileStatement($3, $5); }
           | WHILE LPARENT expression RPARENT EOL scope { $$ = new ast::WhileStatement($3, $6); }
           ;

statements : statement            { $$ = std::vector<ast::Statement*>(); enlist($$, $1); }
           | statements statement { $$ = enlist($1, $2); }
           ;

command    : print   { $$ = $1; }
           | exit    { $$ = $1; }
           | load    { $$ = $1; }
           ;

print      : PRINT list { $$ = new ast::PrintStatement($2); }
           ;

exit       : EXIT { $$ = new ast::ExitStatement; }
           ;

load       : LOAD expression { $$ = new ast::LoadStatement($2); }
           ;

typeof     : TYPEOF expression { $$ = new ast::TypeOf($2); }
           ;

%%

void yy::parser::error(const location_type& l, const std::string& m)
{
  throw yy::parser::syntax_error(l, m);
}

