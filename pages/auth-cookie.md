# Cookie-based 认证授权

这里我们只介绍Asp.Net Core中基于`Cookie`的认证授权使用方式。其认证授权原理参见[Session认证](webapi-security.md/#21-session)。

Cookie-base认证授权方式多用于Web项目。前后端分离的Web项目含App的多端项目一般多使用JWT认证。

## 1. 配置 Authentication
在Startup中注册认证服务，添加认证中间件。

```csharp
public void ConfigureServices(IServiceCollection services)
{
    //注册认证服务
    services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie();

    services.AddMvc().SetCompatibilityVersion(CompatibilityVersion.Version_2_2);
}

public void Configure(IApplicationBuilder app, IHostingEnvironment env)
{
    //添加认证中间件
    app.UseAuthentication();
    app.UseMvc();
}
```

## 2. 登录注销
```csharp
public class AccountController : Controller
{
    public async Task<IActionResult> Login(string userName, string password, string returnUrl)
    {
        if (userName != "admin" || password != "123")
            return Content("用户名或密码错误");

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.Name, userName),
            new Claim(ClaimTypes.Role, "admin")//设置角色
        };

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));

        if (!string.IsNullOrWhiteSpace(returnUrl))
            return Redirect(returnUrl);
        return Ok("登录成功");
    }

    public async Task<IActionResult> Logout()
    {
        await HttpContext.SignOutAsync();
        return Ok("注销成功");
    }
}
```

## 3. 使用认证授权
```csharp
[Authorize(Roles = "admin")]//基于基色验证身份
public class HomeController : Controller
{
    public IActionResult Index()
    {
        return View();
    }
}
```
在需要认证授权的`Controller`或`Action`打上`Authorize`标记即可启用认证。认证不通过默认会导航到`/Account/Login`,授权不通过默认会导航到`/Account/AccessDenied`，也可以在注册服务时修改默认配置。