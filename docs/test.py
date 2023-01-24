import plotly.express as px
import requests

df = px.data.gapminder().query("country=='Canada'")
fig = px.line(df, x="year", y="lifeExp", title='Life expectancy in Canada')
#fig.show()
fig.write_html("index.html", include_plotlyjs='cdn')
