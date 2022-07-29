<div id="top"></div>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![AGPL License][license-shield]][license-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!-- <a href="https://github.com/lenra-io/template-hello-world-node12">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a> -->

<h3 align="center">Application Runner</h3>

  <p align="center">
    This repository provides an Phoenix application that can run Lenra Application.
    <br />
    <br />
    <a href="https://github.com/lenra-io/application-runner/issues">Report Bug</a>
    ·
    <a href="https://github.com/lenra-io/application-runner/issues">Request Feature</a>
  </p>
</div>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

You can run Applicationrunner itself, but in fact the application is built as a library and needs a Phoenix parent application to access all functionality: 
- Add Application Runner to yout project:
```elixir
{:application_runner, git: "https://github.com/lenra-io/application-runner.git", tag: "v1.0.0.beta.X"}
```
- Configure the Library:
```elixir
config :application_runner,
  lenra_environment_table: __,
  lenra_user_table: __,
  repo: __,
  url: __,
```
with:  
- lenra_environment_table: the name of the environment table in String
- lenra_user_table: the name of the user table in String
- repo: Your app reposirtory
- url: url of your application, this url is passed to Lenra application to make API request

- Implement Web socket & Channel:  
   - You also need to implement a channel using Applciationrunner channel

```elixir
defmodule LenraWeb.AppChannel do
  use ApplicationRunner.AppChannel

  defp allow(user_id, app_name) do
    #This function authorizes a user for the following app_name
    #Return true to authorize access
    #Return false to deny access
  end

  defp get_function_name(app_name) do
    #This fucntion return the name of the application to call
  end

  defp get_env(app_name) do
    #This function return the environment of the following app_name
  end
end
```
  - You need to Implement an Socket for your applciation that use ApplciationRunner Socket, here an exxemple:

```elixir
defmodule YourApp.Socket do
  use ApplicationRunner.UserSocket, channel: _Yourchannel
  
  defp resource_from_params(params) do
    # This function validate that the client can open a socket following params
    # To accept the connection return {:ok, _params}
    # To refut the connection return :error 
  end
end
  ```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please open an issue with the tag "enhancement" or "bug".
Don't forget to give the project a star! Thanks again!

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the **AGPL** License. See [LICENSE](./LICENSE) for more information.

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Lenra - [@lenra_dev](https://twitter.com/lenra_dev) - contact@lenra.io

Project Link: [https://github.com/lenra-io/application-runner](https://github.com/lenra-io/application-runner)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/lenra-io/application-runner.svg?style=for-the-badge
[contributors-url]: https://github.com/lenra-io/application-runner/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/lenra-io/application-runner.svg?style=for-the-badge
[forks-url]: https://github.com/lenra-io/application-runner/network/members
[stars-shield]: https://img.shields.io/github/stars/lenra-io/application-runner.svg?style=for-the-badge
[stars-url]: https://github.com/lenra-io/application-runner/stargazers
[issues-shield]: https://img.shields.io/github/issues/lenra-io/application-runner.svg?style=for-the-badge
[issues-url]: https://github.com/lenra-io/application-runner/issues
[license-shield]: https://img.shields.io/github/license/lenra-io/application-runner.svg?style=for-the-badge
[license-url]: https://github.com/lenra-io/application-runner/blob/master/LICENSE.txt