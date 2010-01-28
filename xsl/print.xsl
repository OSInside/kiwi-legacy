<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml"
	omit-xml-declaration="no"
	encoding="utf-8"/>
<xsl:strip-space elements="*"/>

<xsl:template match="/">
	<xsl:apply-templates mode="pretty"/>
</xsl:template>

<xsl:param name="indent-increment" select="'&#9;'"/>

<xsl:template name="newline">
	<xsl:text>&#10;</xsl:text>
</xsl:template>

<xsl:template match="comment() | processing-instruction()" mode="pretty">
	<xsl:param name="indent" select="''"/>
	<xsl:call-template name="newline"/>
	<xsl:value-of select="$indent"/>
	<xsl:copy />
</xsl:template>
  
<xsl:template match="text()" mode="pretty">
	<xsl:param name="indent" select="''"/>
	<xsl:call-template name="newline"/>    
	<xsl:value-of select="$indent"/>
	<xsl:value-of select="normalize-space(.)"/>
</xsl:template>

<xsl:template match="*" mode="pretty">
	<xsl:param name="indent" select="''"/>
	<xsl:call-template name="newline"/>
	<xsl:value-of select="$indent"/>
		<xsl:choose>
			<xsl:when test="count(child::*) > 0">
				<xsl:copy>
				<xsl:copy-of select="@*"/>
				<xsl:apply-templates select="*|text()" mode="pretty">
				<xsl:with-param name="indent" select="concat ($indent, $indent-increment)"/>
				</xsl:apply-templates>
				<xsl:call-template name="newline"/>
				<xsl:value-of select="$indent"/>
				</xsl:copy>
			</xsl:when>       
			<xsl:otherwise>
				<xsl:copy-of select="."/>
			</xsl:otherwise>
		</xsl:choose>
</xsl:template>

</xsl:stylesheet>
