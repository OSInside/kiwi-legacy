<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml"
    indent="yes" omit-xml-declaration="no" encoding="utf-8"/>

<!-- default rule -->
<xsl:template match="*|processing-instruction()|comment()" mode="conv50to51">
	<xsl:copy>
		<xsl:copy-of select="@*"/>
		<xsl:apply-templates mode="conv50to51"/>
	</xsl:copy>  
</xsl:template>

<!-- update schema version -->
<para xmlns="http://docbook.org/ns/docbook">
	Changed attribute <tag class="attribute">schemaversion</tag>
	to <tag class="attribute">schemaversion</tag> from
	<literal>5.0</literal> to <literal>5.1</literal>.
</para>
<xsl:template match="image" mode="conv50to51">
	<image schemaversion="5.1">
		<xsl:copy-of select="@*[local-name() != 'schemaversion']"/>
		<xsl:apply-templates  mode="conv50to51"/>  
	</image>
</xsl:template>

<!-- remove baseroot attribute from type -->
<para xmlns="http://docbook.org/ns/docbook">
	Remove obsolete baseroot attribute from types
</para>
<xsl:template match="type" mode="conv50to51">
	<type>
		<xsl:copy-of select="@*[not(local-name(.) = 'baseroot')]"/>
		<xsl:apply-templates mode="conv20to24"/>
	</type>
</xsl:template>

<!-- remove defaultbaseroot element from preferences -->
<para xmlns="http://docbook.org/ns/docbook">
	Remove defaultbaseroot element from preferences
</para>
<xsl:template match="defaultbaseroot" mode="conv50to51"/>

</xsl:stylesheet>
