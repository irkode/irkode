---
title: Blog posts
permalink: /blog
---

# {{ page.title }}

<ul>
  {% for post in site.posts %}
  <li>
    <a href="{{ post.url }}" class="post-preview">{{ post.title }}</a><br>
    {{ post.excerpt }}
   </li>
  {% endfor %}
</ul>

### By Category

{% for category in site.categories %}
#### {{ category[0] }}
  {% for post in category[1] %}
* <a href="{{ post.url }}">{{ post.title }}</a>
  {% endfor %}
{% endfor %}

### By Tag

{% for tag in site.tags %}
#### {{ tag[0] }}
  {% for post in tag[1] %}
* <a href="{{ post.url }}">{{ post.title }}</a>
  {% endfor %}
{% endfor %}