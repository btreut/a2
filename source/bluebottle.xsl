<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" />
<xsl:template match="/">
<html>
  <body style="font-family:Arial,helvetica,sans-serif;font-size:12pt;background-color:#FFFFFF">
    <pre><font style="font-family:Arial,helvetica,sans-serif;font-size:10pt">
    <xsl:for-each select="Text/Span">
      <xsl:choose>   
	      <xsl:when test="@style = 'Normal'">
		      <span style="font-weight:normal;color:black;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span>
	      </xsl:when>	
	      <xsl:when test="@style = 'Bold'">
		      <span style="font-weight:bold;color:black;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>	      
	      <xsl:when test="@style = 'Comment'">
		      <span style="font-weight:normal;color:gray;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>       	      
	      <xsl:when test="@style = 'Debug'">
		      <span style="font-weight:normal;color:blue;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>	      
	      <xsl:when test="@style = 'Assertion'">
		      <span style="font-weight:bold;color:blue;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>       
	      <xsl:when test="@style = 'Lock'">
		      <span style="font-weight:normal;color:#FF00FF;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>            
	      <xsl:when test="@style = 'Stupid'">
		      <span style="font-weight:normal;color:red;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>       	      
	      <xsl:when test="@style = 'Preferred'">
		      <span style="font-weight:bold;color:#880088;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>	      
	      <xsl:when test="@style = 'Highlight'">
		      <span style="font-weight:normal;font-style:italic;color:black;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:when>	      
	      <xsl:otherwise>
		      <span style="font-weight:normal;color:orange;font-size:10pt">
		        <xsl:value-of select="."/>
		      </span> 
	      </xsl:otherwise>      
      </xsl:choose>            
    </xsl:for-each>
    </font></pre>  
  </body> 
</html>
</xsl:template>
</xsl:stylesheet>