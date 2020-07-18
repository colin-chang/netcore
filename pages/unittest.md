# 单元测试

- [单元测试](#单元测试)
  - [1. 单元测试简介](#1-单元测试简介)
    - [1.1 单元测试作用](#11-单元测试作用)
    - [1.2 单元测试必要性](#12-单元测试必要性)
    - [1.3 TDD](#13-tdd)
    - [1.4 单元测试的正确姿势](#14-单元测试的正确姿势)
  - [2. .NET单元测试](#2-net单元测试)
    - [2.1 Attributes](#21-attributes)
    - [2.2 Assertions](#22-assertions)
    - [2.3 Xunit示例](#23-xunit示例)

## 1. 单元测试简介
单元测试是针对程序的最小单元来进行正确性检验的测试工作，程序单元就是应用的最小可测试部件，一个单元可能是单个程序，类，对象，方法等。单元测试的想法是写一个方法之前就想好这个方法有什么样的输入输出,在开发完成就 测试一下给定的输出是不是产生期望的输出。

### 1.1 单元测试作用
* 减少bug

    单元测试的目的就是通过足够准确的测试用例保证代码逻辑是正确。所以，在单测过程中，必然可以解决一些bug。因为，一旦某条测试用例没有通过，那么我们就会修改被测试的代码来保证能够通过测试。

* 减少修复bug的成本

    一般解决bug的思路都是先通过各种手段定位问题，然后在解决问题。定位问题的时候如果没有单元测试，就只能通过debug的方式一点一点的追踪代码。解决问题的时候更是需要想尽各种方法来重现问题，然后改代码，改了代码之后在集成测试。

    因为单元规模较小，复杂性较低，因而发现错误后容易隔离和定位，有利于调试工作。

* 帮助重构，提高重构的成功率
    我相信，对一个程序员来说最痛苦的事就是修改别人的代码。有时候，一个很大的系统会导致很多人不敢改，因为他不知道改了一个地方会不会导致其他地方出错。可以，一旦有了单元测试，开发人员可以很方便的重构代码，只要在重构之后跑一遍单元测试就可以知道是不是把代码“改坏了”

* 提高开发速度
    不写单测也许能让开发速度更快，但是无法保证自己写出来的代码真的可以正确的执行。写单测可以较少很多后期解决bug的时间。也能让我们放心的使用自己写出来的代码。整体提高开发速度。

### 1.2 单元测试必要性
单元测试可以在软件开发过程的早期就能发现问题。从表面上看，为每个单元程序都编写测试代码似乎是增加了工作量，但是其实这些代码不仅为你织起了一张保护网，而且还可以帮助你快速定位错误从而使你大大减少修复BUG的时间。只要单测的测试用例足够好，那么就可以避免很多低级错误。好的单测不仅不会浪费时间，还会大大节省我们的时间。

其实单元测试不仅能保证项目进度还能优化你的设计。设计的程序耦合度也越来越低。每个单元程序的输入输出，业务内容和异常情况都会尽可能变得简单。

### 1.3 TDD
Test-Driven Development, 测试驱动开发， 是敏捷开发的一项核心实践和技术，也是一种设计方法论。TDD原理是开发功能代码之前，先编写测试用例代码，然后针对测试用例编写功能代码，使其能够通过。由于TDD对开发人员要求非常高，跟传统开发思维不一样，因此实施起来相当困难。

![TTD](https://i.loli.net/2020/02/26/uIyZdrqC8lW3O5V.jpg)

测试驱动开发有好处也有坏处。因为每个测试用例都是根据需求来的，或者说把一个大需求分解成若干小需求编写测试用例，所以测试用例写出来后，开发者写的执行代码，必须满足测试用例。如果测试不通过，则修改执行代码，直到测试用例通过。

### 1.4 单元测试的正确姿势
* 越重要的代码，越要写单元测试；
* 代码做不到单元测试，多思考如何改进，而不是放弃；
* 边写业务代码，边写单元测试，而不是完成整个新功能后再写；
* 多思考如何改进、简化测试代码。

## 2. .NET单元测试
.NET中常见的测试框架有MSTest、Nunit和Xunit,目前比较流行的是Xunit。作为NUnit的改进版，xUnit.Net确实克服了NUnit的不少缺点。xUnit.Net的Assert更精简但是又足以满足单元测试的需要，相比之下NUnit的Assert API略显臃肿。

### 2.1 Attributes
NUnit 3.x|MSTest 15.x|xUnit.net 2.x|Comments
:-|:-|:-|:-
[Test]|[TestMethod]|[Fact]|Marks a test method.
[TestFixture]|[TestClass]|n/a|xUnit.net does not require an attribute for a test class; it looks for all test methods in all public (exported) classes in the assembly.
[ExpectedException]|[ExpectedException]|Assert.ThrowsRecord.Exception|xUnit.net has done away with the ExpectedException attribute in favor of Assert.Throws.
[SetUp]|[TestInitialize]|Constructor|We believe that use of [SetUp] is generally bad. However, you can implement a parameterless constructor as a direct replacement.
[TearDown]|[TestCleanup]|IDisposable.Dispose|We believe that use of [TearDown] is generally bad. However, you can implement IDisposable.Dispose as a direct replacement.
[OneTimeSetUp]|[ClassInitialize]|IClassFixture<T>|To get per-class fixture setup, implement IClassFixture<T> on your test class.
[OneTimeTearDown]|[ClassCleanup]|IClassFixture<T>|To get per-class fixture teardown, implement IClassFixture<T> on your test class.
n/a|n/a|ICollectionFixture<T>|To get per-collection fixture setup and teardown, implement ICollectionFixture<T> on your test collection.
[Ignore("reason")]|[Ignore]|[Fact(Skip="reason")]|Set the Skip parameter on the [Fact] attribute to temporarily skip a test.
[Property]|[TestProperty]|[Trait]|Set arbitrary metadata on a test
n/a|[DataSource]|[Theory],[XxxData]|Theory (data-driven test).

### 2.2 Assertions

NUnit 3.x (Constraint)|MSTest 15.x|xUnit.net 2.x|Comments
:-|:-|:-|:-
Is.EqualTo|AreEqual|Equal|MSTest and xUnit.net support generic versions of this method
Is.Not.EqualTo|AreNotEqual|NotEqual|MSTest and xUnit.net support generic versions of this method
Is.Not.SameAs|AreNotSame|NotSame|
Is.SameAs|AreSame|Same|
Does.Contain|Contains|Contains|
Does.Not.Contain|DoesNotContain|DoesNotContain|
Throws.Nothing|n/a|n/a|Ensures that the code does not throw any exceptions. See Note 5
n/a|Fail|n/a|xUnit.net alternative: Assert.True(false, "message")
Is.GreaterThan|n/a|n/a|xUnit.net alternative: Assert.True(x > y)
Is.InRange|n/a|InRange|Ensures that a value is in a given inclusive range
Is.AssignableFrom|n/a|IsAssignableFrom|
Is.Empty|n/a|Empty|
Is.False|IsFalse|FALSE|
Is.InstanceOf<T>|IsInstanceOfType|IsType<T>|
Is.NaN|n/a|n/a|xUnit.net alternative: Assert.True(double.IsNaN(x))
Is.Not.AssignableFrom<T>|n/a|n/a|xUnit.net alternative: Assert.False(obj is Type)
Is.Not.Empty|n/a|NotEmpty|
Is.Not.InstanceOf<T>|IsNotInstanceOfType|IsNotType<T>|
Is.Not.Null|IsNotNull|NotNull|
Is.Null|IsNull|Null|
Is.True|IsTrue|TRUE|
Is.LessThan|n/a|n/a|xUnit.net alternative: Assert.True(x < y)
Is.Not.InRange|n/a|NotInRange|Ensures that a value is not in a given inclusive range
Throws.TypeOf<T>|n/a|Throws<T>|Ensures that the code throws an exact exception

### 2.3 Xunit示例
xUnit基本使用参见https://xunit.github.io/docs/getting-started/netfx/visual-studio

```csharp
public class TemplateTest : IClassFixture<TempateFixture>
{
    private readonly TempateFixture _fixture;

    //相当于[TestInitialize]
    public TemplateTest(TempateFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public void Test1()
    {
        Assert.Equal("Colin",_fixture.Name);
    }

    [Fact]
    public void Test2()
    {
        Assert.True(true);
    }
}

public class TempateFixture : IDisposable
{
    public string Name { get; set; }

    //相当于[ClassInitialize]
    public TempateFixture()
    {
        //数据初始化
        Name = "Colin";
    }

    //相当于[ClassCleanup]
    public void Dispose()
    {
        //数据清理
        Name = null;
    }
}
```

TempateFixture中构造函数和Dispose在单个或多个测试用例都只会执行一次。TemplateTest中构造函数和Dispose(如果直接实现IDisposable)则会在每个测试方法都执行一次。

单元测试应该符合可以重复执行的原则，所以我们通常会在测试结束后对测试产生的变化或恢复和清理，如删除产生的过程数据等。测试贡献和清理数据参见https://xunit.github.io/docs/shared-context

如果需要在单元测试中输出内容需要使用ITestOutputHelper对象，直接注入即可。
```csharp
public class TemplateTest
{
    private readonly ITestOutputHelper _testOutputHelper;
    public TemplateTest(ITestOutputHelper testOutputHelper)
    {
        _testOutputHelper = testOutputHelper;
    }

    [Fact]
    public void SaveAsTest()
    {
        _testOutputHelper.WriteLine("测试输出...");
    }
}
```

实际案例可以参考 
https://github.com/colin-chang/MongoHelper/blob/master/ColinChang.OpenSource.MongoHelper.Test/MongoHelperTest.cs