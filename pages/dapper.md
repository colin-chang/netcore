# Dapper快速入门

## 1. 简介
Dapper是.NET下一个轻量级的ORM框架，它和Entity Framework或Nhibnate不同，属于轻量级的，并且是半自动的。也就是说实体类都要自己写。它没有复杂的配置文件，一个单文件就可以了。Dapper通过提供IDbConnection扩展方法来进行工作。

Dapper相当于 SqlHelper部分功能 + AutoMapper
## 2. 简单CRUD
下面我们通过一个简单的.Net Core控制台项目来快速入门Dappper使用。数据库使用MySQL。

### 2.1 创建项目
```sh
# 创建.net core控制台项目
$ dotnet new console -n DapperDemo

# 引用Dapper和MySQL nuget包
$ dotnet add package Dapper
$ dotnet add package MySql.Data
```
### 2.2 数据模型
#### 1) 数据库
![数据库结构](../img/dapper/db-structure.jpg)
```sql
CREATE TABLE `article` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `Title` varchar(255) NOT NULL,
  `Content` text NOT NULL,
  `Status` int(1) NOT NULL DEFAULT '1',
  `UpdateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `AuthorId` int(11) NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `author` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `NickName` varchar(255) NOT NULL,
  `RealName` varchar(255) NOT NULL,
  `BirthDate` date DEFAULT NULL,
  `Address` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `comment` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `ArticleId` int(11) NOT NULL,
  `Content` varchar(255) NOT NULL,
  `CreateTime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```
#### 2) 数据模型
```csharp
public abstract class BaseModel
{
    public int Id { get; set; }
}

public class Author : BaseModel
{
    public string NickName { get; set; }

    public string RealName { get; set; }

    public DateTime? BirthDate { get; set; }

    public string Address { get; set; }

    public Author() { }

    public Author(string nickName, string realName)
    {
        NickName = nickName;
        RealName = realName;
    }
}

public class Article : BaseModel
{
    public string Title { get; set; }

    public string Content { get; set; }

    public int Status { get; set; }

    public DateTime UpdateTime { get; set; }

    public int AuthorId { get; set; }

    public Author Author { get; set; }

    public IEnumerable<Comment> Comments { get; set; }
}

public class Comment : BaseModel
{
    public int ArticleId { get; set; }

    public Article Article { get; set; }

    public string Content { get; set; }

    public DateTime CreateTime { get; set; }
}
```
### 2.3 非查询操作
我们对非查询操作进行简单封装一个DapperHelper

```csharp
static class DapperHelper
{
    public async static Task<int> ExecuteAsync(string sql, params object[] parameters)
    {
        using (var conn = GetConnection())
        {
            return await conn.ExecuteAsync(sql, parameters == null || parameters.Length <= 0 ? null : parameters);
        }
    }

    public async static Task<object> QueryScalarAsync(string sql, object parameter = null)
    {
        using (var conn = GetConnection())
        {
            return await conn.ExecuteScalarAsync(sql, parameter);
        }
    }

    //Dapper查询操作参数不支持集合，如Array和List
    public async static Task<IEnumerable<T>> QueryAsync<T>(string sql, object parameter = null)
        where T : class, new()
    {
        using (var conn = GetConnection())
        {
            return await conn.QueryAsync<T>(sql, parameter);
        }
    }

    public async static Task<IEnumerable<TReturn>> QueryAsync<TFirst, TSecond, TReturn>(string sql, Func<TFirst, TSecond, TReturn> map, object parameter = null)
        where TFirst : class, new()
        where TSecond : class, new()
        where TReturn : class, new()
    {
        using (var conn = GetConnection())
        {
            return await conn.QueryAsync<TFirst, TSecond, TReturn>(sql, map, parameter);
        }
    }

    public async static Task<IEnumerable<TReturn>> QueryAsync<TFirst, TSecond, TThird, TReturn>(string sql, Func<TFirst, TSecond, TThird, TReturn> map, object parameter = null)
        where TFirst : class, new()
        where TSecond : class, new()
        where TThird : class, new()
        where TReturn : class, new()
    {
        using (var conn = GetConnection())
        {
            return await conn.QueryAsync<TFirst, TSecond, TThird, TReturn>(sql, map, parameter);
        }
    }

    public async static Task<IEnumerable<IEnumerable<object>>> QueryMultipleAsync(IEnumerable<string> sqls, object parameter = null)
    {
        using (var conn = GetConnection())
        {
            var reader = await conn.QueryMultipleAsync(string.Join(";", sqls), parameter);
            var results = new IEnumerable<object>[sqls.Count()];
            for (int i = 0; i < sqls.Count(); i++)
                results[i] = await reader.ReadAsync();

            return results;
        }
    }

    public async static Task<(IEnumerable<TFirst> Result1, IEnumerable<TSecond> Result2)> QueryMultipleAsync<TFirst, TSecond>(string sqls, object parameter = null)
        where TFirst : class, new()
        where TSecond : class, new()
    {
        using (var conn = GetConnection())
        {
            var reader = await conn.QueryMultipleAsync(sqls, parameter);
            var result1 = await reader.ReadAsync<TFirst>();
            var result2 = await reader.ReadAsync<TSecond>();

            return (result1, result2);
        }
    }

    public async static Task<(IEnumerable<TFirst> Result1, IEnumerable<TSecond> Result2, IEnumerable<TThird> Result3)> QueryMultipleAsync<TFirst, TSecond, TThird>(string sqls, object parameter = null)
        where TFirst : class, new()
        where TSecond : class, new()
        where TThird : class, new()
    {
        using (var conn = GetConnection())
        {
            var reader = await conn.QueryMultipleAsync(sqls, parameter);
            var result1 = await reader.ReadAsync<TFirst>();
            var result2 = await reader.ReadAsync<TSecond>();
            var Result3 = await reader.ReadAsync<TThird>();

            return (result1, result2, Result3);
        }
    }

    private static IDbConnection GetConnection()
    {
        string connStr = "Server=127.0.0.1;Database=db_dapper;Uid=root;Pwd=xinzhe&468SQL;";
        return new MySqlConnection(connStr);
    }
}
```
#### 1) 插入数据
Dapper可以使用同样的方式插入一条或多条数据。
```csharp
string sql = "INSERT INTO author (NickName,RealName) VALUES(@nickName,@RealName)";
var colin = new Author("Colin", "Colin Chang");
var robin = new Author("Robin", "Robin Song");

//await DapperHelper.ExecuteAsync(sql,new List<Author>{colin,robin});
await DapperHelper.ExecuteAsync(sql, colin, robin);
```
#### 2) 更新数据
```csharp
string sql = "UPDATE author SET Address=@address WHERE Id=@id";
await DapperHelper.ExecuteAsync(sql, new { id = 1, address = "山东" });

/*
string sql = "UPDATE author SET Address=@address WHERE NickName=@nickName";
await DapperHelper.ExecuteAsync(sql, new { nickName = "Robin", address = "河南" });
*/
```
#### 3) 删除数据
```csharp
string sql = "DELETE FROM author WHERE Id=@id";
await DapperHelper.ExecuteAsync(sql,new {id=2});
```

### 2.4 查询操作
#### 1) 简单查询
```csharp            
var sql = "SELECT * FROM author";
var authors = await DapperHelper.QueryAsync<Author>(sql);
```
#### 2) 条件查询
```csharp
var sql = "SELECT * FROM author WHERE Id=@id";
var authors = await DapperHelper.QueryAsync<Author>(sql, new { id = 1 });
var author = authors.FirstOrDefault();
```
常用的`IN ()`方式查询
```csharp
var sql = "SELECT * FROM author WHERE Id IN @ids";
var authors = await DapperHelper.QueryAsync<Author>(sql, new { ids = new int[] { 1, 2 } });
```
#### 3) 多表连接查询
此处使用三表连接查询，包含`1:1`和`1:N`的关系。
```csharp
var sql = @"SELECT * FROM
                article AS ar
                JOIN author AS au ON ar.AuthorId = au.Id
                LEFT JOIN `comment` AS c ON ar.Id = c.ArticleId";
var articles = new Dictionary<int, Article>();
var data = await DapperHelper.QueryAsync<Article, Author, Comment,Article>(sql,
(article, author, comment) =>
{
    //1:1
    article.Author=author;

    //1:N
    if (!articles.TryGetValue(article.Id, out Article articleEntry))
    {
        articleEntry = article;
        articleEntry.Comments = new List<Comment>{};
        articles.Add(article.Id, articleEntry);
    }
    articleEntry.Comments.Add(comment);
    return articleEntry;
});
// var result= data.Distinct();
var result=articles.Values;
```
`1:N`关系的连接查，查询出来的数据都是连接展开之后的全部数据记录，以上代码中的Lambda表达式会在遍历没条数据记录时执行一次。


#### 4) 多结果集查询
Dapper支持多结果集查询，可以执行任意多条查询语句。
```csharp
// 多结果集查询
// 1.JSON方式
string sql1 = "SELECT * FROM article WHERE Id=@id";
string sql2 = "SELECT * FROM `comment` WHERE ArticleId=@articleId";
var data = await DapperHelper.QueryMultipleAsync(new string[] { sql1, sql2 }, new { id = 1, articleId = 1 });
var article = data.ElementAt(0).ElementAt(0).ToString();//JSON

// 2.泛型方式
string sqls = @"
    SELECT * FROM article WHERE Id=@id;
    SELECT * FROM `comment` WHERE ArticleId=@articleId;";
(IEnumerable<Article> Articles, IEnumerable<Comment> comments) = await DapperHelper.QueryMultipleAsync<Article, Comment>(sqls, new { id = 1, articleId = 1 });
Article article = Articles.FirstOrDefault();
if (article != null)
    article.Comments = Comments;
```
多结果集查询中，配合使用多条存在一定关联关系的查询语句，可以在一定程上巧妙的实现连接查询的效果，避免多表连接查询锁表的问题。以上泛型方式代码即实现了此种效果。

## 3. 存储过程和事务
### 3.1 存储过程

### 3.2 事务